export class DeviceImp {
  getInfo(params?: Record<string, Object>): Record<string, Object> {
    console.info('[ASCF][DeviceImp] getInfo')

    const result: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    result['deviceName'] = 'Mock HarmonyOS Device'
    result['os'] = 'HarmonyOS'
    result['stage'] = 'DeviceBiz -> DeviceImp'
    result['note'] = 'Step 6 uses mock data. Step 7 will call OpenHarmony API.'
    return result
  }
}
