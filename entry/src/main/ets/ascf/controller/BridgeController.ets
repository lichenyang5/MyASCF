import { BridgeRequest, parseBridgeRequest } from '../protocol/BridgeRequest'
import {
  BridgeResponse,
  errorResponse,
  CODE_PARAMS_ERROR
} from '../protocol/BridgeResponse'
import { BridgeDispatcher } from '../dispatcher/BridgeDispatcher'

export type BridgeCallbackToH5 = (responseJson: string) => void

export class BridgeController {
  private readonly callbackToH5: BridgeCallbackToH5
  private readonly dispatcher: BridgeDispatcher

  constructor(callbackToH5: BridgeCallbackToH5, dispatcher: BridgeDispatcher) {
    this.callbackToH5 = callbackToH5
    this.dispatcher = dispatcher
  }

  async handle(rawReq: string): Promise<void> {
    console.info(`[ASCF][Controller] rawReq = ${rawReq}`)

    let response: BridgeResponse
    try {
      const req: BridgeRequest = parseBridgeRequest(rawReq)
      console.info(`[ASCF][Controller] parsed request action = ${req.action}`)
      response = await this.dispatcher.dispatch(req)
    } catch (e) {
      const errMsg: string = (e as Error).message
      console.error(`[ASCF][Controller] parse error: ${errMsg}`)
      const emptyData: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      response = errorResponse('', CODE_PARAMS_ERROR, errMsg, emptyData)
    }

    const responseJson: string = JSON.stringify(response)
    console.info(`[ASCF][Controller] response = ${responseJson}`)
    this.callbackToH5(responseJson)
  }
}
