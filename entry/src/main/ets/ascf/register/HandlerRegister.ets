import { BridgeRequest } from '../protocol/BridgeRequest'
import { BridgeResponse, successResponse } from '../protocol/BridgeResponse'
import { BridgeHandler } from '../handler/BridgeHandler'
import { RuntimeImp } from '../imp/RuntimeImp'
import { RuntimeBiz } from '../biz/RuntimeBiz'
import { DeviceImp } from '../imp/DeviceImp'
import { DeviceBiz } from '../biz/DeviceBiz'

export class HandlerRegister {
  private readonly handlers: Map<string, BridgeHandler> = new Map<string, BridgeHandler>()
  private readonly runtimeImp: RuntimeImp = new RuntimeImp()
  private readonly runtimeBiz: RuntimeBiz = new RuntimeBiz(this.runtimeImp)
  private readonly deviceImp: DeviceImp = new DeviceImp()
  private readonly deviceBiz: DeviceBiz = new DeviceBiz(this.deviceImp)

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
    this.register('runtime.ping', (req: BridgeRequest): BridgeResponse => {
      return this.runtimeBiz.ping(req)
    })

    console.info('[ASCF][Register] bind action runtime.echo to RuntimeBiz.echo')
    this.register('runtime.echo', (req: BridgeRequest): BridgeResponse => {
      return this.runtimeBiz.echo(req)
    })

    console.info('[ASCF][Register] bind action device.getInfo to DeviceBiz.getInfo')
    this.register('device.getInfo', (req: BridgeRequest): BridgeResponse => {
      return this.deviceBiz.getInfo(req)
    })

    this.register('runtime.controllerPing', (req: BridgeRequest): BridgeResponse => {
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
