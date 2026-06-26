import { WebRuntimePage } from './WebRuntimePage'

@Entry
@Component
struct Index {
  build() {
    Column(){
      WebRuntimePage()
    }
  }
}
