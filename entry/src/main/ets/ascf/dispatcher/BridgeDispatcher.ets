import { BridgeRequest } from '../protocol/BridgeRequest'
import {
  BridgeResponse,
  errorResponse,
  CODE_UNKNOWN_ACTION,
  CODE_NATIVE_ERROR
} from '../protocol/BridgeResponse'
import { BridgeHandler } from '../handler/BridgeHandler'
import { HandlerRegister } from '../register/HandlerRegister'

export class BridgeDispatcher {
  private readonly register: HandlerRegister

  constructor(register: HandlerRegister) {
    this.register = register
  }

  async dispatch(request: BridgeRequest): Promise<BridgeResponse> {
    console.info(`[ASCF][Dispatcher] dispatch action = ${request.action}`)

    const handler: BridgeHandler | undefined = this.register.getHandler(request.action)

    if (handler === undefined) {
      const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      data['action'] = request.action
      return errorResponse(
        request.requestId,
        CODE_UNKNOWN_ACTION,
        `UNKNOWN_ACTION: ${request.action}`,
        data
      )
    }

    try {
      return await handler(request)
    } catch (e) {
      const errMsg: string = (e as Error).message
      console.error(`[ASCF][Dispatcher] handler error: ${errMsg}`)
      const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      data['action'] = request.action
      data['reason'] = errMsg
      return errorResponse(
        request.requestId,
        CODE_NATIVE_ERROR,
        'Handler execute failed',
        data
      )
    }
  }
}
