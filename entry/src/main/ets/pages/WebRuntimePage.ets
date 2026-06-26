import webview from '@ohos.web.webview'
import { AscfBridgeObject } from '../ascf/bridge/AscfBridgeObject'

const TAG: string = 'WebRuntimePage'

@Component
export struct WebRuntimePage {
  private controller: webview.WebviewController = new webview.WebviewController()
  private bridge: AscfBridgeObject = new AscfBridgeObject()

  build() {
    Column() {
      Web({
        src: $rawfile('h5/index.html'),
        controller: this.controller
      })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'ascfBridge',
          methodList: ['send'],
          controller: this.controller
        })
        .onPageBegin((event) => {
          console.info(`${TAG} onPageBegin url=${event?.url ?? ''}`)
        })
        .onPageEnd((event) => {
          console.info(`${TAG} onPageEnd url=${event?.url ?? ''}`)
        })
    }
    .width('100%')
    .height('100%')
  }
}
