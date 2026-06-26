import { BridgeRequest } from '../protocol/BridgeRequest'
import {
  BridgeResponse,
  successResponse,
  errorResponse,
  CODE_PARAMS_ERROR
} from '../protocol/BridgeResponse'
import { NativeImp } from '../imp/NativeImp'

export class NativeBiz {
  private readonly imp: NativeImp

  constructor(imp: NativeImp) {
    this.imp = imp
  }

  async addByNapi(request: BridgeRequest): Promise<BridgeResponse> {
    console.info('[ASCF][NativeBiz] addByNapi')

    let a: number = 0
    let b: number = 0
    let aOk: boolean = false
    let bOk: boolean = false

    const params: Record<string, Object> | undefined = request.params
    if (params !== undefined) {
      const aVal: Object = params['a']
      if (typeof aVal === 'number') {
        a = aVal as number
        aOk = true
      }
      const bVal: Object = params['b']
      if (typeof bVal === 'number') {
        b = bVal as number
        bOk = true
      }
    }

    if (!aOk || !bOk) {
      const errData: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      errData['action'] = request.action
      return errorResponse(
        request.requestId,
        CODE_PARAMS_ERROR,
        'native.addByNapi requires number params.a and params.b',
        errData
      )
    }

    const data: Record<string, Object> = this.imp.addByNapi(a, b)
    data['action'] = request.action
    return successResponse(request.requestId, 'native.addByNapi success', data)
  }

  async getNativeVersion(request: BridgeRequest): Promise<BridgeResponse> {
    console.info('[ASCF][NativeBiz] getNativeVersion')
    const data: Record<string, Object> = this.imp.getNativeVersion()
    data['action'] = request.action
    return successResponse(request.requestId, 'native.getNativeVersion success', data)
  }
}
