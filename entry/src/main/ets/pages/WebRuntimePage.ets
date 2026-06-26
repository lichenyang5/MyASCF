import webview from '@ohos.web.webview'

const TAG: string = 'WebRuntimePage'

@Component
export struct WebRuntimePage {
  private controller: webview.WebviewController = new webview.WebviewController()

  build() {
    Column() {
      Web({
        src: $rawfile('h5/index.html'),
        controller: this.controller
      })
        .width('100%')
        .height('100%')
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
