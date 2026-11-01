// Tạo capacitor.config.json từ cấu hình (biến môi trường hoặc sweetgram.json)
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
const file = existsSync('sweetgram.json') ? JSON.parse(readFileSync('sweetgram.json', 'utf8')) : {}
const c = {
  url: process.env.SWEETGRAM_URL || file.url || 'https://susosweet.levals.org',
  appId: process.env.SWEETGRAM_APP_ID || file.appId || 'org.levals.sweetgram',
  name: process.env.SWEETGRAM_APP_NAME || file.name || 'Sweetgram',
  team: process.env.SWEETGRAM_TEAM_ID || file.team || '',
  version: process.env.SWEETGRAM_VERSION || file.version || '1.0',
  build: process.env.SWEETGRAM_BUILD || file.build || String(Math.floor(Date.now() / 60000) % 2000000000),
}
const host = new URL(c.url).host
writeFileSync('capacitor.config.json', JSON.stringify({
  appId: c.appId,
  appName: c.name,
  webDir: 'www',
  server: { url: c.url.replace(/\/?$/, '/'), allowNavigation: [
    host,
    'www.paypal.com', '*.paypal.com', '*.paypalobjects.com',
    // YouTube "Xem chung": cho phép WebView nạp script IFrame API, khung nhúng và luồng video
    'www.youtube.com', '*.youtube.com', 'youtube-nocookie.com', 'www.youtube-nocookie.com',
    's.ytimg.com', 'i.ytimg.com', '*.ytimg.com', '*.googlevideo.com',
    'www.google.com', '*.gstatic.com', '*.ggpht.com',
  ], errorPath: 'offline.html' },
  ios: { contentInset: 'never', limitsNavigationsToAppBoundDomains: false, backgroundColor: '#b86cff', scheme: 'Sweetgram' },
  plugins: { PushNotifications: { presentationOptions: ['badge', 'sound', 'alert'] } },
}, null, 2))
writeFileSync('www/config.js', `window.SG_URL = ${JSON.stringify(c.url.replace(/\/?$/, '/'))}\n`)
writeFileSync('scripts/.resolved.json', JSON.stringify(c, null, 2))
console.log('▶ Sweetgram iOS:', c)
