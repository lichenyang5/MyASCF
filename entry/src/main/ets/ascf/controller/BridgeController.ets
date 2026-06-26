import { BridgeRequest, parseBridgeRequest } from '../protocol/BridgeRequest'
import {
  BridgeResponse,
  successResponse,
  errorResponse,
  CODE_PARAMS_ERROR
} from '../protocol/BridgeResponse'

export type BridgeCallbackToH5 = (responseJson: string) => void

export class BridgeController {
  private readonly callbackToH5: BridgeCallbackToH5

  constructor(callbackToH5: BridgeCallbackToH5) {
    this.callbackToH5 = callbackToH5
  }

  handle(rawReq: string): void {
    console.info(`[ASCF][Controller] rawReq = ${rawReq}`)

    let response: BridgeResponse
    try {
      const req: BridgeRequest = parseBridgeRequest(rawReq)
      console.info(`[ASCF][Controller] parsed request = ${JSON.stringify(req)}`)

      const emptyParams: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      const params: Record<string, Object> = req.params ?? emptyParams

      const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      data['action'] = req.action
      data['stage'] = 'BridgeController'
      data['receivedParams'] = params
      data['explain'] = 'BridgeController parsed BridgeRequest and built BridgeResponse'

      response = successResponse(req.requestId, 'ok', data)
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
