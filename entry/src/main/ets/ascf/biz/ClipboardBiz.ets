import { BridgeRequest } from '../protocol/BridgeRequest'
import {
  BridgeResponse,
  successResponse,
  errorResponse,
  CODE_PARAMS_ERROR
} from '../protocol/BridgeResponse'
import { ClipboardImp } from '../imp/ClipboardImp'

export class ClipboardBiz {
  private readonly imp: ClipboardImp

  constructor(imp: ClipboardImp) {
    this.imp = imp
  }

  async writeText(request: BridgeRequest): Promise<BridgeResponse> {
    console.info('[ASCF][ClipboardBiz] writeText')

    let text: string = ''
    const params: Record<string, Object> | undefined = request.params
    if (params !== undefined) {
      const raw: Object = params['text']
      if (typeof raw === 'string') {
        text = raw as string
      }
    }

    if (text.length === 0) {
      const errData: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      errData['action'] = request.action
      return errorResponse(
        request.requestId,
        CODE_PARAMS_ERROR,
        'clipboard.writeText requires params.text',
        errData
      )
    }

    const impResult: Record<string, Object> = await this.imp.writeText(text)
    impResult['action'] = request.action
    return successResponse(request.requestId, 'clipboard.writeText success', impResult)
  }

  async readText(request: BridgeRequest): Promise<BridgeResponse> {
    console.info('[ASCF][ClipboardBiz] readText')

    const impResult: Record<string, Object> = await this.imp.readText()
    impResult['action'] = request.action
    return successResponse(request.requestId, 'clipboard.readText success', impResult)
  }
}
