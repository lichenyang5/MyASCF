import { BridgeRequest } from '../protocol/BridgeRequest'
import { BridgeResponse, successResponse } from '../protocol/BridgeResponse'
import { BridgeHandler } from '../handler/BridgeHandler'
import { RuntimeImp } from '../imp/RuntimeImp'
import { RuntimeBiz } from '../biz/RuntimeBiz'
import { DeviceImp } from '../imp/DeviceImp'
import { DeviceBiz } from '../biz/DeviceBiz'
import { ClipboardImp } from '../imp/ClipboardImp'
import { ClipboardBiz } from '../biz/ClipboardBiz'
import { NativeImp } from '../imp/NativeImp'
import { NativeBiz } from '../biz/NativeBiz'

export class HandlerRegister {
  private readonly handlers: Map<string, BridgeHandler> = new Map<string, BridgeHandler>()
  private readonly runtimeImp: RuntimeImp = new RuntimeImp()
  private readonly runtimeBiz: RuntimeBiz = new RuntimeBiz(this.runtimeImp)
  private readonly deviceImp: DeviceImp = new DeviceImp()
  private readonly deviceBiz: DeviceBiz = new DeviceBiz(this.deviceImp)
  private readonly clipboardImp: ClipboardImp = new ClipboardImp()
  private readonly clipboardBiz: ClipboardBiz = new ClipboardBiz(this.clipboardImp)
  private readonly nativeImp: NativeImp = new NativeImp()
  private readonly nativeBiz: NativeBiz = new NativeBiz(this.nativeImp)

  constructor() {
    this.registerDefaults()
  }

  register(action: string, handler: BridgeHandler): void {
    console.info(`[ASCF][Register] register action = ${action}`)
    this.handlers.set(action, handler)
  }

  getHandler(action: string): BridgeHandler | undefined {
    console.info(`[ASCF][Register] getHandler action = ${action}`)
    return this.handlers.get(action)
  }

  hasHandler(action: string): boolean {
    return this.handlers.has(action)
  }

  listActions(): string[] {
    const actions: string[] = []
    this.handlers.forEach((value: BridgeHandler, key: string) => {
      actions.push(key)
    })
    return actions
  }

  private registerDefaults(): void {
    console.info('[ASCF][Register] bind action runtime.ping to RuntimeBiz.ping')
    this.register('runtime.ping', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return this.runtimeBiz.ping(req)
    })

    console.info('[ASCF][Register] bind action runtime.echo to RuntimeBiz.echo')
    this.register('runtime.echo', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return this.runtimeBiz.echo(req)
    })

    console.info('[ASCF][Register] bind action device.getInfo to DeviceBiz.getInfo')
    this.register('device.getInfo', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return this.deviceBiz.getInfo(req)
    })

    console.info('[ASCF][Register] bind action clipboard.writeText to ClipboardBiz.writeText')
    this.register('clipboard.writeText', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return await this.clipboardBiz.writeText(req)
    })

    console.info('[ASCF][Register] bind action clipboard.readText to ClipboardBiz.readText')
    this.register('clipboard.readText', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return await this.clipboardBiz.readText(req)
    })

    console.info('[ASCF][Register] bind action native.addByNapi to NativeBiz.addByNapi')
    this.register('native.addByNapi', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return await this.nativeBiz.addByNapi(req)
    })

    console.info('[ASCF][Register] bind action native.getNativeVersion to NativeBiz.getNativeVersion')
    this.register('native.getNativeVersion', async (req: BridgeRequest): Promise<BridgeResponse> => {
      return await this.nativeBiz.getNativeVersion(req)
    })

    this.register('runtime.controllerPing', async (req: BridgeRequest): Promise<BridgeResponse> => {
      const emptyParams: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      const params: Record<string, Object> = req.params ?? emptyParams

      const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      data['action'] = req.action
      data['stage'] = 'HandlerRegister -> runtime.controllerPing'
      data['text'] = 'controller pong'
      data['receivedParams'] = params

      return successResponse(req.requestId, 'runtime.controllerPing success', data)
    })
  }
}
