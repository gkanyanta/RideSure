import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { MatchingService } from './matching.service';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/ws',
})
export class MatchingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(MatchingGateway.name);

  constructor(
    private jwtService: JwtService,
    private matchingService: MatchingService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token || client.handshake.headers?.authorization?.split(' ')[1];
      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token);
      client.data.userId = payload.sub;
      client.data.role = payload.role;

      // Join user-specific room
      client.join(`user:${payload.sub}`);

      if (payload.role === 'RIDER') {
        client.join('riders');
      }

      this.logger.log(`Client connected: ${payload.sub} (${payload.role})`);
    } catch (err) {
      this.logger.warn(`Auth failed: ${err.message}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    if (client.data.userId) {
      this.logger.log(`Client disconnected: ${client.data.userId}`);
    }
  }

  @SubscribeMessage('rider:location')
  async handleRiderLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { lat: number; lng: number },
  ) {
    if (client.data.role !== 'RIDER') return;
    await this.matchingService.updateRiderLocation(client.data.userId, data.lat, data.lng);
  }

  @SubscribeMessage('trip:request')
  async handleTripRequest(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { tripId: string },
  ) {
    if (client.data.role !== 'PASSENGER') return;
    this.logger.log(`Trip request from passenger ${client.data.userId}: ${data.tripId}`);
    await this.matchingService.startMatching(data.tripId, this.server);
  }

  @SubscribeMessage('trip:accept')
  async handleTripAccept(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { tripId: string },
  ) {
    if (client.data.role !== 'RIDER') return;
    this.logger.log(`Trip accepted by rider ${client.data.userId}: ${data.tripId}`);
    await this.matchingService.acceptTrip(data.tripId, client.data.userId, this.server);
  }

  @SubscribeMessage('trip:reject')
  async handleTripReject(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { tripId: string },
  ) {
    if (client.data.role !== 'RIDER') return;
    await this.matchingService.rejectOffer(data.tripId, client.data.userId, this.server);
  }

  // Emit helpers used by services
  emitToUser(userId: string, event: string, data: any) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  emitToRider(riderId: string, event: string, data: any) {
    this.server.to(`user:${riderId}`).emit(event, data);
  }
}
