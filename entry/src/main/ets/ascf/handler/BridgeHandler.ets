import { BridgeRequest } from '../protocol/BridgeRequest'
import { BridgeResponse } from '../protocol/BridgeResponse'

export type BridgeHandler = (request: BridgeRequest) => Promise<BridgeResponse>
