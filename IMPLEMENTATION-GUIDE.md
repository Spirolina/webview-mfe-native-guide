# WebView Microfrontend Hızlandırma — Native Uygulama Rehberi

> **Bu rehber başka bir kod tabanında çalışan bir AI ajanına verilmek üzere yazılmıştır.**
> Kendi kendine yeter: bu repoya, bu laba veya başka bir dosyaya erişim gerektirmez.

---

## ⛔ KAPSAM — bunu ilk okuyun, sonrası buna bağlı

**Bu rehber YALNIZCA native tarafı ele alır (iOS + Android).**

| | |
|---|---|
| ✅ Değişecek | Native host uygulama: WebView yaşam döngüsü, havuz, köprü, enjekte edilen script, cookie/oturum aktarımı, reveal, ölçüm |
| ❌ Değişmeyecek | Microfrontend'lerin React kaynak kodu |
| ❌ Yazılmayacak | Yeni bir microfrontend, demo MFE, test MFE'si, `/warmup` route'u |
| ⚠️ Ayrı tutulan | Web ekiplerinden **istenebilecek** şeyler → [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü) — bunlar bu işin kapsamı değil, yalnızca tavanın nerede olduğunu gösterir |

**Mevcut microfrontend'ler olduğu gibi kalır.** Native taraf onları var oldukları
hâliyle, **kaynak koduna dokunmadan** hızlandırmak zorundadır.

Bunun bir bedeli var ve rehber bu bedeli her fazda açıkça yazar:

> **Native-only tavan daha düşük ve daha kırılgandır.**
>
> Referans ölçümde **ölçülmüş** iki native-only sonuç var: `about:blank` ile
> sıcak havuz **−13%**, kalıcı paylaşılan WebView **−37%**. Web işbirliği
> gerektiren `/warmup` + route swap varyantı da **−37%**. Aradaki asıl fark
> hızda değil **kırılganlıkta**: native-only'de route swap ve hazır-olma
> sinyali birer **sezgidir**, MFE'nin haber vermeden değişebilecek davranışına
> dayanır (Faz 3.4, Faz 5.3).
>
> Bu rehber o sezgileri kurar, doğrulama ve fallback'lerini yazdırır ve
> web işbirliğinin ne kazandıracağını ölçülebilir hâle getirir.

### Native-only nasıl mümkün oluyor

Tek mekanizma: **native, sayfaya kendi JavaScript'ini enjekte edebilir.**

- iOS: `WKUserScript(injectionTime: .atDocumentStart)`
- Android: `WebViewCompat.addDocumentStartJavaScript`

Bu script, MFE'nin kendi kodu çalışmadan **önce** çalışır. Yani native;
ölçüm problarını, `fetch`/XHR sayaçlarını, route sürücüsünü ve hazır-olma
sezgisini **MFE'ye tek satır yazmadan** kurabilir. Rehberin tamamı bunun üstünde durur.

---

## 🛑 HARD STOP — keşif bitmeden kod yazılmaz

Bu rehberdeki hiçbir kod **kopyala-yapıştır değildir** ve hiçbir faz
"her uygulamada işe yarar" değildir. Faz 0 bir formalite değil, **kapı**dır.

```
Faz 0  KEŞİF  →  envanter raporu  →  KULLANICI ONAYI  →  ancak sonra kod
```

**AI ajanı için kural:** [`00-kesif.md`] (bu dosyada: Faz 0 — Keşif bölümü)'deki envanter raporunu
doldurup kullanıcıya sunmadan ve onay almadan **hiçbir dosyayı değiştirmeyin.**
Rapordaki bir alan "bulunamadı" kalıyorsa, o alana bağlı fazı **varsayımla
uygulamayın** — kullanıcıya sorun.

Sebebi somut: bu rehberdeki tekniklerin en az dördü, mevcut yapıya bağlı olarak
**sessizce hiçbir şey yapmaz** ve siz "uyguladım" dersiniz:

| Teknik | Mevcut yapı şuysa sessizce ölür |
|---|---|
| Route swap (`history.pushState`) | Router hash tabanlıysa veya `popstate` dinlemiyorsa |
| Sıcak havuz | WebView her ekranda `Fragment`/`ViewController` içinde yeniden yaratılıyorsa ve havuzdan alma yolu yoksa |
| documentStart enjeksiyonu | WebView config'i ekran yaratıldıktan sonra kuruluyorsa |
| Hazır-olma sezgisi | Sayfa sürekli polling/websocket yapıyorsa (in-flight sayacı hiç sıfırlanmaz) |
| Android `startUpWebView` | Aynı frame'de WebView yaratılıyorsa |

---

## Faz sırası — bozmayın

```
Faz 0  KEŞİF               ← KAPI. Envanter + onay olmadan ilerlemek yasak.
  ↓
Faz 1  ÖLÇÜM               ← zorunlu. Atlarsanız hangi fazın işe yaradığını bilemezsiniz.
  ↓
Faz 2  HIZLI KAZANIMLAR    ← ucuz, risksiz, ölçüm beklemeden yapılabilir
  ↓
Faz 3  SICAK WEBVIEW       ← en büyük tek native kazanç. Buradan sonrası ölçüme bağlı.
  ↓
Faz 4  AUTH + OTURUM       ← ölçümünüz redirect maliyeti gösteriyorsa
  ↓
Faz 5  REVEAL              ← ürün kararı: yarım ekran mı, bekleme mi?
  ↓
Faz 6  KALICI WEBVIEW      ← yapısal, en yüksek maliyet, en yüksek tavan
  ↓
Faz 7  İLERİ SEVİYE        ← yerel asset, speculative loading
```

| Dosya | İçerik | Native-only mi? |
|---|---|---|
| [`00-kesif.md`] (bu dosyada: Faz 0 — Keşif bölümü) | **Envanter, karar matrisi, onay kapısı** | ✅ |
| [`01-olcum.md`] (bu dosyada: Faz 1 — Ölçüm bölümü) | Enjekte edilen ölçüm probu — MFE'ye dokunmadan faz tablosu | ✅ |
| [`02-hizli-kazanimlar.md`] (bu dosyada: Faz 2 — Hızlı kazanımlar bölümü) | Cookie sırası, beyaz flash, process termination, Android pre-warm | ✅ (cache header'ları hariç) |
| [`03-sicak-webview.md`] (bu dosyada: Faz 3 — Sıcak WebView bölümü) | Sıcak havuz + native route swap + ısınmayı susturma — **çekirdek** | ✅ |
| [`04-auth-ve-veri.md`] (bu dosyada: Faz 4 — Auth bölümü) | Redirect zincirini kritik yoldan çıkarma, oturum aktarımı | ✅ |
| [`05-reveal.md`] (bu dosyada: Faz 5 — Reveal bölümü) | "Hazır olmadan gösterme" + native hazır-olma sezgisi | ✅ |
| [`06-kalici-webview.md`] (bu dosyada: Faz 6 — Kalıcı WebView bölümü) | Tek paylaşılan WebView, re-parenting, screenshot | ✅ |
| [`07-ileri-seviye.md`] (bu dosyada: Faz 7 — İleri seviye bölümü) | Yerel asset servisi, prerender/prefetch | ✅ |
| [`08-dogrulama.md`] (bu dosyada: Faz 8 — Doğrulama bölümü) | Kabul kriterleri, anti-pattern listesi, çürütülen iddialar | ✅ |
| [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü) | **Kapsam dışı.** Web ekiplerinden istenecekler ve karşılığında ne kazanılır | ❌ |

---

## Ölçülmüş referans sonuçlar

Aşağıdaki sayılar bu rehberin türetildiği referans uygulamadan gelir:
**iOS 26.3 Simulator, 1954 KB React bundle, 7 ekran, ekran başına 2-3 paralel API çağrısı,
bankacılık benzeri gecikme profili (p50 180–1200 ms), n=22.**

| Strateji | Native-only? | Ekran açıldı p50 | Baseline'a göre |
|---|---|---|---|
| Cold baseline (her ekranda yeni WebView) | — | 903 ms | — |
| Process prewarm (yarat-at) | ✅ | 953 ms | **daha kötü** |
| Sıcak WebView (`about:blank`) | ✅ | 790 ms | −13% |
| Sıcak + `/warmup` + route swap | ❌ web gerekli | 565 ms | −37% |
| Sıcak + `/warmup` + preauth | ❌ web gerekli | 522 ms | −42% |
| Kalıcı paylaşılan WebView | ✅ | 565 ms | −37% |

> **Native-only için okunacak iki satır:**
> `about:blank` sıcak havuz −13% ile taban; **kalıcı paylaşılan WebView** (Faz 6)
> web işbirliği gerektirmeden −37%'ye ulaşan tek yoldur. Faz 3'teki
> "mevcut bir hafif route'a ısınma" yaklaşımı bu ikisinin arasında bir yerde
> durur ve **referans ölçümde bu varyant ayrıca ölçülmemiştir** — kendi
> uygulamanızda ölçün (§03.6).

**Faz kırılımı — asıl anlatılan şey bu:**

| Faz | Cold | Sıcak + route swap |
|---|---|---|
| WebView + doküman + JS boot + route mount | **397 ms** | **22 ms** |
| Veri bekleme (paralel servislerin en yavaşı) | 435 ms | 497 ms |
| Çizim + reveal | 71 ms | 46 ms |

> **Sıcak strateji JS zincirini 18 kat kısaltıyor — ama toplam yalnızca %37 düşüyor,
> çünkü veri beklemesine hiç dokunamıyor.**
>
> Kendi uygulamanızda bu oran tamamen farklı olabilir. JS payınız büyükse kazanç
> büyük, backend payınız büyükse kazanç küçük olur. **Faz 1 bunu söyler.**

### ⚠️ Bu sayıların sınırları

- **Simulator ölçümü.** Gerçek telefonda JS parse/compile orta segmentte **3–4×**,
  ucuz cihazda **6×+** daha yavaştır ([V8, 2019](https://v8.dev/blog/cost-of-javascript-2019)).
  Bu, sıcak stratejinin **mutlak** kazancını büyütür.
- **Localhost ağı.** Gerçek şebekede ağ payı büyür.
- **Gecikme profili varsayımdır**, ölçüm değil. Kendi APM değerlerinizle düşünün.
- Referans uygulamada MFE **işbirliği yapıyordu** (`/warmup` route'u vardı).
  Sizde olmayacak. Bu yüzden referans sayıları **üst sınır** olarak okuyun.
- Bu rehberdeki hiçbir "şu kadar ms kazandırır" iddiası sizin uygulamanız için
  geçerli değildir. Oranlar fikir verir, sayılar vermez.


---

# Faz 0 — Keşif ve envanter (KAPI — atlanamaz)

**Amaç:** Kod yazmadan önce mevcut yapıyı tespit etmek ve hangi fazın bu kod
tabanında **gerçekten** uygulanabilir olduğunu belirlemek.

**Süre:** 1-3 gün · **Risk:** yok · **Çıktı:** doldurulmuş envanter raporu

---

## 0.0 🛑 AI ajanı için kesin kural

> **Bu fazın çıktısı olan envanter raporunu kullanıcıya sunup onay almadan
> hiçbir dosyayı değiştirmeyin.**
>
> Rapordaki bir alan **"bulunamadı"** kalıyorsa:
> - O alana bağlı fazı **varsayımla uygulamayın.**
> - "Muhtemelen şöyledir" diye ilerlemek yerine **kullanıcıya sorun.**
> - Raporda o satırı `❓ SORULACAK` olarak işaretleyin.
>
> Bu bir nezaket kuralı değil. §0.6'daki tablo, yanlış varsayımla uygulanan
> fazların **hiçbir hata vermeden, sessizce sıfır kazanç** ürettiğini gösteriyor.
> O durumda ekip haftalarca "uyguladık ama fark etmedi" der ve sebebini bulamaz.

Rapor hazır olduğunda kullanıcıya şu cümleyle sunun:

> *"Envanteri çıkardım. Şu fazlar uygulanabilir: … . Şunlar bu kod tabanında
> çalışmaz veya doğrulanamadı: … . Şunları netleştirmem gerek: … .
> Onaylarsanız Faz 1'den (ölçüm) başlıyorum."*

---

## 0.1 Statik keşif — iOS

Aşağıdaki aramaları **sırayla** koşun ve bulgularını rapora yazın.
(`rg` yoksa `grep -rn` kullanın.)

```bash
# 1. WebView nerede yaratılıyor? — en kritik soru
rg -n 'WKWebView\s*\(' --glob '*.swift' --glob '*.m' --glob '*.mm'

# 2. Konfigürasyon nerede kuruluyor? (enjeksiyon buraya girecek)
rg -n 'WKWebViewConfiguration|WKUserContentController|WKPreferences' --glob '*.swift'

# 3. Halihazırda enjekte edilen script / köprü var mı?
rg -n 'addUserScript|WKUserScript|add\(.*name:|WKScriptMessageHandler' --glob '*.swift'

# 4. Süreç ve veri deposu paylaşımı
rg -n 'WKProcessPool|websiteDataStore|WKWebsiteDataStore' --glob '*.swift'

# 5. Delegate'ler — redirect ve termination görünürlüğü
rg -n 'WKNavigationDelegate|didReceiveServerRedirect|WebContentProcessDidTerminate|decidePolicyFor' --glob '*.swift'

# 6. Oturum WebView'e nasıl giriyor?
rg -n 'httpCookieStore|HTTPCookieStorage|setCookie|Authorization|setValue\(.*forHTTPHeaderField' --glob '*.swift'

# 7. Yükleme çağrıları ve URL kaynağı
rg -n 'load\(URLRequest|loadHTMLString|loadFileURL|setURLSchemeHandler' --glob '*.swift'

# 8. Zaten JS çalıştırılıyor mu?
rg -n 'evaluateJavaScript|callAsyncJavaScript' --glob '*.swift'

# 9. Profiling ve içerik engelleme yetenekleri
rg -n 'isInspectable|WKContentRuleList' --glob '*.swift'

# 10. MFE URL'leri nerede tanımlı? (host adlarını görün)
rg -n 'https://' --glob '*.swift' --glob '*.plist' --glob '*.json' | rg -v 'apple.com|schemas' | head -50
```

### iOS'ta cevaplanması gerekenler

| Soru | Nasıl anlaşılır |
|---|---|
| WebView **ekran başına mı** yaratılıyor? | (1)'in sonucu bir `ViewController`/`View` içindeyse evet |
| Ortak bir **factory** var mı? | (1) tek bir yerde toplanıyorsa, değişiklik yüzeyi küçük |
| `WKWebViewConfiguration` **WebView'den önce mi** kuruluyor? | (2) ile (1)'in sırasına bakın — sonraysa Faz 2.3 gerekli |
| Halihazırda bir **köprü** var mı? | (3) sonuç veriyorsa onu kullanın, yenisini kurmayın |
| `WKProcessPool` paylaşılıyor mu? | (4) |
| `navigationDelegate` **atanmış mı**? | (5) — atanmamışsa redirect'i native tarafta sayamazsınız |

---

## 0.2 Statik keşif — Android

```bash
# 1. WebView nerede yaratılıyor / tanımlanıyor?
rg -n 'WebView\s*\(' --glob '*.kt' --glob '*.java'
rg -n '<WebView|androidx.webkit' --glob '*.xml' --glob '*.gradle*'

# 2. Halihazırda köprü var mı?
rg -n 'addJavascriptInterface|@JavascriptInterface|WebMessage|postWebMessage' --glob '*.kt' --glob '*.java'

# 3. İstek araya girme — enjeksiyon ve engelleme yüzeyi
rg -n 'shouldInterceptRequest|shouldOverrideUrlLoading|WebViewClient|WebViewClientCompat' --glob '*.kt' --glob '*.java'

# 4. Oturum aktarımı
rg -n 'CookieManager|setCookie|acceptCookie|addHeader|Authorization' --glob '*.kt' --glob '*.java'

# 5. Yükleme çağrıları — file:// veya loadData kullanılıyor mu? (Faz 2.7)
rg -n 'loadUrl|loadData|loadDataWithBaseURL|WebViewAssetLoader' --glob '*.kt' --glob '*.java'

# 6. Ayarlar ve profiling
rg -n 'WebSettings|javaScriptEnabled|domStorageEnabled|setWebContentsDebuggingEnabled' --glob '*.kt' --glob '*.java'

# 7. androidx.webkit sürümü — bu, hangi API'lerin kullanılabileceğini belirler
rg -n 'androidx.webkit' --glob '*.gradle*' --glob '*.toml'

# 8. documentStart enjeksiyonu mümkün mü?
rg -n 'addDocumentStartJavaScript|DOCUMENT_START_SCRIPT|WebViewFeature' --glob '*.kt' --glob '*.java'
```

### Android'de cevaplanması gerekenler

| Soru | Neden kritik |
|---|---|
| `androidx.webkit` **sürümü kaç**? | `< 1.16.0` ise `startUpWebView` yok; `DOCUMENT_START_SCRIPT` desteği sürüme ve **WebView provider sürümüne** bağlı |
| `addDocumentStartJavaScript` **kullanılabilir mi**? | Kullanılamıyorsa enjeksiyonu `shouldInterceptRequest` ile HTML'e yazmak gerekir — daha kırılgan, raporda belirtin |
| Zaten bir `WebViewClient` alt sınıfı var mı? | Varsa engelleme/enjeksiyon oraya eklenir, paralel bir tane kurulmaz |
| `loadData`/`file://` kullanılıyor mu? | Kullanılıyorsa **`fetch()` çalışmıyordur** — bu başlı başına bir bug (Faz 2.7) |

---

## 0.3 Çalışma zamanı keşfi — MFE'ye dokunmadan

Bu adımlar **kod değiştirmeden**, sadece inspector ile yapılır ve Faz 3/5'in
uygulanabilir olup olmadığını belirler.

**Nasıl bağlanılır:**
- **Android:** `WebView.setWebContentsDebuggingEnabled(true)` (debug build'de) → `chrome://inspect`
- **iOS:** `webView.isInspectable = true` (iOS 16.4+) → Safari ▸ Geliştirici menüsü

### A. Router tipi — **Faz 3'ün route swap'i buna bağlı**

Uygulama içinde bir ekrandan diğerine geçin ve konsoldan izleyin:

```js
// Geçişten ÖNCE ve SONRA çalıştırın, farkı not edin
JSON.stringify({ pathname: location.pathname, hash: location.hash, search: location.search })
```

| Gözlem | Router tipi | Native route swap yöntemi |
|---|---|---|
| `pathname` değişiyor, sayfa yeniden yüklenmiyor | **history/browser router** | `history.pushState` + sentetik `popstate` |
| `hash` değişiyor | **hash router** | `location.hash = '...'` (en güvenilir yol) |
| Sayfa tamamen yeniden yükleniyor | **SPA değil / MPA** | Route swap **uygulanamaz** — Faz 3 yalnızca `about:blank` havuzuna iner |

Ayrıca **doğrulayın** — bu tahminle geçilmez:

```js
// history router'da: bu komut gerçekten ekranı değiştiriyor mu?
history.pushState({}, '', '/hedef-route');
window.dispatchEvent(new PopStateEvent('popstate', { state: history.state }));
// 1 sn bekleyin, ekran değişti mi?
```

> 🚨 **Değişmiyorsa Faz 3'ün route swap kısmı bu uygulamada çalışmaz.**
> Bazı router sürümleri kendi iç indeksini tutar ve sentetik `popstate`'i yok sayar.
> Raporda `route-swap: ÇALIŞMIYOR` yazın ve Faz 3'ü yalnızca havuz kısmıyla uygulayın.

### B. Mevcut global'ler ve köprüler

```js
// MFE zaten native'e bir yüzey açıyor mu?
Object.keys(window).filter(k => /^__|bridge|native|mfe|app/i.test(k))
// iOS'ta native'in açtığı kanallar
Object.keys(window.webkit?.messageHandlers ?? {})
```

### C. Redirect zinciri — **Faz 4'ün önceliği buna bağlı**

```js
const n = performance.getEntriesByType('navigation')[0];
({ redirectMs: n.redirectEnd - n.redirectStart, type: n.type, ttfb: Math.round(n.responseStart) })
```

### D. Bundle profili — **Faz 7'nin önceliği buna bağlı**

```js
performance.getEntriesByType('resource')
  .filter(r => r.initiatorType === 'script' || r.initiatorType === 'link')
  .map(r => ({ url: r.name.split('/').pop(), kb: Math.round(r.transferSize/1024),
               cached: r.transferSize === 0, ms: Math.round(r.duration) }))
```

### E. ⚠️ Sürekli ağ trafiği var mı — **Faz 5'in hazır-olma sezgisi buna bağlı**

Bir ekranı açın, **hiçbir şeye dokunmadan 30 saniye bekleyin** ve Network panelini izleyin.

| Gözlem | Sonuç |
|---|---|
| İlk yükten sonra ağ **tamamen susuyor** | ✅ In-flight sayacı sezgisi çalışır (Faz 5.3) |
| Düzenli aralıklarla istek gidiyor (polling) | ⚠️ Sezgi için **yok sayma listesi** gerekir |
| WebSocket / SSE / long-poll açık | 🚨 In-flight sayacı **hiç sıfırlanmaz** — sezgi çalışmaz, DOM tabanlı sezgiye düşün |

### F. Ekran başına istek sayısı — **Faz 5'in maliyeti buna bağlı**

Her WebView ekranı için Network panelinde XHR/fetch sayısını ve **en yavaşını** not edin.
Ekran açılış süresi, toplamları değil **en yavaşın** süresine yakınsar (paralelse).

### G. Analitik nasıl gönderiliyor — **Faz 3'ün ısınma susturması buna bağlı**

Bir ekranı açın ve Network'te ekran görüntüleme event'inin **hangi host'a**
gittiğini not edin. Faz 3'te bu host ısınma sırasında engellenecek.

```js
// Beacon kullanılıyor mu? (Network panelinde 'ping'/'beacon' tipi olarak görünür)
typeof navigator.sendBeacon
```

---

## 0.4 Envanter raporu — bu şablonu doldurun

```markdown
## WebView Envanteri

### Kapsam
- WebView ile açılan ekran sayısı:          ____
- Ayrı microfrontend (origin/bundle) sayısı: ____
- Host adları:                               ____

### iOS
- WebView yaratma yeri (dosya:satır):        ____
- Ekran başına mı, paylaşılan factory mi:    ____
- Configuration WebView'den önce kuruluyor:  evet / hayır
- Mevcut script message handler:             var (ad: ____) / yok
- Mevcut documentStart user script:          var / yok
- navigationDelegate atanmış:                evet / hayır
- websiteDataStore:                          default / ayrı / bilinmiyor
- Oturum aktarımı:                           cookie / header / URL / WebView içi login
- isInspectable kullanılabilir:              evet / hayır

### Android
- WebView yaratma yeri (dosya:satır):        ____
- androidx.webkit sürümü:                    ____
- addDocumentStartJavaScript destekli:       evet / hayır / bilinmiyor
- Mevcut JavascriptInterface:                var (ad: ____) / yok
- Mevcut WebViewClient alt sınıfı:           var (dosya: ____) / yok
- shouldInterceptRequest kullanılıyor:       evet / hayır
- loadData / file:// kullanılıyor:           evet (🚨 bug) / hayır
- Oturum aktarımı:                           cookie / header / URL / WebView içi login

### Web tarafı (çalışma zamanı gözlemi — kod değiştirilmedi)
- Router tipi:                               history / hash / MPA
- Sentetik popstate ile route swap:          ÇALIŞIYOR / ÇALIŞMIYOR / test edilmedi
- Mevcut window global'leri:                 ____
- Navigation redirect süresi:                ____ ms
- Entry bundle boyutu:                       ____ KB (chunk sayısı: ____)
- Boştayken ağ trafiği:                      susuyor / polling / websocket
- Ekran başına XHR sayısı (min–max):         ____
- En yavaş servis (p50 gözlem):              ____ ms
- Analitik host'u:                           ____
- Service Worker:                            var / yok

### Uygulanabilirlik kararı
| Faz | Durum | Gerekçe |
|---|---|---|
| 1 Ölçüm            | ✅ / ❓ | |
| 2 Hızlı kazanımlar | ✅ / ❓ | |
| 3 Sıcak WebView    | ✅ / ⚠️ kısmi / ❌ | |
| 4 Auth             | ✅ / ❓ / ❌ | |
| 5 Reveal           | ✅ / ⚠️ sezgi kırılgan / ❌ | |
| 6 Kalıcı WebView   | ✅ / ❌ | |
| 7 İleri seviye     | ✅ / ❌ | |

### ❓ Kullanıcıya sorulacaklar
- ...
```

---

## 0.5 Kullanıcıya sorulacak sabit sorular

Bunlar kodda **bulunamaz**, sormak zorundasınız:

1. **Ürün kararı:** Ekran yarım çizilmiş hâlde mi açılsın, yoksa veri hazır olana
   kadar native spinner mı görünsün? *(Faz 5'in tamamı buna bağlı; teknik değil
   ürün tercihidir ve geri alınması pahalıdır.)*
2. **Bellek bütçesi:** Uygulama arka planda kaç WebView tutabilir? En düşük
   desteklenen cihaz hangisi? *(Faz 3'ün havuz boyutu ve Faz 6 buna bağlı.)*
3. **Web ekipleriyle ilişki:** Microfrontend'lere ileride değişiklik talep
   edilebilir mi, yoksa tamamen dokunulmaz mı? *(Evetse
   [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü) gündeme girer; hayırsa native-only
   tavanı kabul edilmiş olur.)*
4. **Profiling:** Release-configuration build'de profiling flag'i açılabilir mi,
   yoksa ayrı bir internal build mi gerekir? *(Faz 1.7.)*
5. **Isınma hedefi:** Uygulamada **veri çekmeyen, analitik göndermeyen** bir route
   var mı (hata sayfası, yasal metin, "hakkında", boş liste)? *(Faz 3.3'ün en iyi
   native-only ısınma hedefi budur.)*
6. **Güvenlik onayı:** Native'in WebView'e oturum enjekte etmesi güvenlik ekibince
   onaylanmış mı? *(Faz 4.5'teki ödünler.)*

---

## 0.6 Bulgu → faz karar matrisi

Envanteri doldurduktan sonra bu tabloyu uygulayın.

| Bulgu | Sonuç |
|---|---|
| Router **hash** tabanlı | Route swap `location.hash` ile yapılır — **daha güvenilir**, Faz 3 tam uygulanır |
| Router **history** + sentetik popstate çalışıyor | Faz 3 tam uygulanır |
| Router **history** + sentetik popstate **çalışmıyor** | Faz 3 yalnızca `about:blank` havuzu olarak uygulanır (≈ −13%); route swap **yazılmaz** |
| **MPA** (her ekran tam sayfa yükleme) | Faz 3 ve 6 büyük ölçüde geçersiz; Faz 2, 4, 7'ye odaklanın |
| `addDocumentStartJavaScript` **yok** (Android) | Ölçüm probu ve sezgi kırılgan — raporda belirtin, iOS'ta önce doğrulayın |
| Boştayken **websocket/polling** var | Faz 5 in-flight sezgisi **kullanılmaz**; DOM sezgisi + zaman aşımı |
| Redirect süresi **> 0** | Faz 4 en yüksek önceliğiniz |
| Redirect süresi **= 0** | Faz 4'ü atlayın, Faz 3'e geçin |
| Ekran başına **1 servis**, hızlı | Faz 5'in maliyeti düşük, uygulanabilir |
| Ekran başına **5+ servis** veya p95 > 1.5 sn | Faz 5 ekranı **yavaşlatır**; önce backend/BFF konuşun (Faz 5.7) |
| WebView **ekran başına yaratılıyor**, ortak factory yok | Faz 3 öncesi bir **refactor** gerekir; bunu ayrı bir iş kalemi olarak raporlayın |
| Mevcut köprü **var** | Yeni köprü kurmayın; mevcut kanala yeni mesaj tipi ekleyin |
| `loadData` / `file://` kullanılıyor | Bu bir bug — `fetch()` çalışmıyordur. Faz 2.7'yi **önce** düzeltin |

---

## 0.7 Kabul kriterleri

- [ ] §0.1 ve §0.2'deki tüm aramalar koşuldu, sonuçlar rapora yazıldı
- [ ] §0.3'teki çalışma zamanı gözlemleri **gerçek uygulamada** yapıldı (tahmin değil)
- [ ] Route swap denemesi **fiilen konsolda test edildi** ve sonucu yazıldı
- [ ] Boştayken ağ trafiği 30 sn izlendi
- [ ] Envanter raporu dolduruldu, boş alanlar `❓ SORULACAK` işaretlendi
- [ ] §0.5'teki sorular kullanıcıya soruldu
- [ ] Uygulanabilirlik tablosu dolduruldu
- [ ] **Rapor kullanıcıya sunuldu ve onay alındı**

> Bu kutulardan biri bile boşken Faz 1'e geçmeyin.


---

# Faz 1 — Ölçüm (zorunlu ön koşul, native-only)

**Amaç:** Ekran açılışını fazlara bölüp her fazın ms maliyetini görmek —
**microfrontend kaynak koduna tek satır yazmadan.**

Bu tablo olmadan sonraki hiçbir fazın size ne kazandıracağını bilemezsiniz.

**Süre:** 2-5 gün · **Risk:** yok · **Geri alınabilir:** evet

> **Ön koşul:** [`00-kesif.md`] (bu dosyada: Faz 0 — Keşif bölümü) tamamlandı ve onaylandı.

---

## 1.1 Native-only ölçüm nasıl mümkün

MFE kendi faz mark'larını göndermiyor. Ama native, sayfaya **MFE'nin kodundan
önce** çalışan bir prob enjekte edebilir:

| Mekanizma | iOS | Android |
|---|---|---|
| Enjeksiyon | `WKUserScript(injectionTime: .atDocumentStart)` | `WebViewCompat.addDocumentStartJavaScript` |
| Geri kanal | `window.webkit.messageHandlers.<ad>.postMessage` | `addJavascriptInterface` |

Prob şunları **MFE'nin işbirliği olmadan** görür:

- Doküman yaşam döngüsü (`doc-start`, `dom-interactive`, `DOMContentLoaded`, `load`)
- `fetch` / `XMLHttpRequest` başlangıç-bitişleri ve **uçuştaki istek sayısı**
- Ağın sustuğu an (`net-quiet`) — **veri hazır olmanın vekil göstergesi**
- DOM'da anlamlı içeriğin ilk belirdiği an (`first-content`)
- `paint` girdileri (FCP) ve — Chromium'da — LCP
- SPA route değişimleri (`history.pushState`/`replaceState`/`popstate` yamalanarak)

**Görmediği tek şey:** MFE'nin *kendi* "ben hazırım" tanımı. Onun yerine
**ağ + DOM sezgisi** kullanılır. Bu bir **vekildir, kesinlik değildir** —
§1.6'da kalitesi nasıl ölçülür yazıyor.

---

## 1.2 Ölçülecek fazlar

```
t0 = kullanıcı dokundu (native, monoton saat)
 │
 ├─ native.webview-ready     WebView elde edildi (yaratıldı ya da havuzdan alındı)
 ├─ native.attached          view hierarchy'ye kondu
 ├─ native.nav-start         navigasyon başladı        (delegate)
 ├─ native.redirect ×N       her sunucu yönlendirmesi   (delegate)   ← Faz 4 buna bakar
 ├─ native.committed         ilk byte geldi, render başlıyor (delegate)
 ├─ doc-start                prob çalıştı = JS motoru ayakta       (prob)
 ├─ dom-interactive          parse bitti                            (prob)
 ├─ route-change             SPA route değişti                      (prob)
 ├─ xhr-first                ilk veri isteği çıktı                  (prob)
 ├─ net-quiet                uçuştaki istek 0'a düştü ve öyle kaldı (prob)  ← veri hazır vekili
 ├─ first-content            DOM'da anlamlı içerik belirdi          (prob)
 ├─ fcp                      ilk içerikli boyama                    (prob)
 └─ screen-ready             native ekranı gösterdi   ← ANA METRİK  (native, Faz 5)
```

**Sıcak stratejilerde `doc-start` / `dom-interactive` hiç görünmez** — o iş zaten
dokunmadan önce yapılmıştır. **Sütunun boş olması hata değil, kazancın kendisidir.**

---

## 1.3 Tek kural: her şey `t0`'a göre

Prob **asla mutlak zaman göndermez.** Sadece *"şu faza geldim"* der; farkı native
hesaplar. Böylece iki ayrı saati senkronize etme problemi hiç doğmaz.

```swift
// iOS — monoton saat. Sistem saati değişse bile kaymaz. Date() KULLANMAYIN.
var t0: CFTimeInterval = 0
func onTap() { t0 = CACurrentMediaTime() }

func received(tag: String, phase: String, payload: [String: Any]) {
    let ms = (CACurrentMediaTime() - t0) * 1000
    guard ms >= 0 else { return }    // t0 öncesi (ısınma) mesajlarını sayma
    samples[phase] = ms
}
```

```kotlin
// Android
val ms = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
if (ms >= 0) samples[phase] = ms
```

---

## 1.4 Prob — enjekte edilecek JavaScript

Bu dosyayı **native kaynak ağacına** koyun (ör. `Resources/webview-probe.js`).
MFE reposuna **girmez**.

```js
// webview-probe.js — native tarafından documentStart'ta enjekte edilir.
// MFE'nin hiçbir kodu bu dosyadan haberdar değildir.
(function () {
  if (window.__probe) return;                 // çift enjeksiyona karşı
  var P = (window.__probe = { marks: [], inflight: 0, ignored: 0 });

  // ── Keşif çıktısından doldurun (00-kesif §0.3-E ve §0.3-G) ───────────────
  // Sayaca DAHİL EDİLMEYECEK istekler: analitik, telemetri, polling, SSE.
  var IGNORE = [/\/analytics\//, /\/telemetry\//, /\/beacon/, /\/ping/];
  var QUIET_MS = 150;                         // "ağ sustu" için sessizlik eşiği
  var CONTENT_CHARS = 120;                    // "anlamlı içerik" eşiği
  // ─────────────────────────────────────────────────────────────────────────

  function post(type, data) {
    var m = Object.assign({ type: type, t: Math.round(performance.now()) }, data || {});
    P.marks.push(m);
    try { window.webkit.messageHandlers.probe.postMessage(m); } catch (e) {}
    try { window.__ProbeBridge.post(JSON.stringify(m)); } catch (e) {}
  }
  P.post = post;

  var ignore = function (u) { return IGNORE.some(function (r) { return r.test(String(u)); }); };

  // ── 1. Doküman yaşam döngüsü ────────────────────────────────────────────
  post('doc-start', { url: location.href });
  document.addEventListener('readystatechange', function () {
    if (document.readyState === 'interactive') post('dom-interactive');
  });
  document.addEventListener('DOMContentLoaded', function () { post('dom-content-loaded'); });
  window.addEventListener('load', function () {
    var n = performance.getEntriesByType('navigation')[0];
    post('load', n ? {
      redirectMs: Math.round(n.redirectEnd - n.redirectStart),
      ttfb: Math.round(n.responseStart),
      domInteractive: Math.round(n.domInteractive),
    } : {});
  });

  // ── 2. Ağ: uçuştaki istek sayısı + sessizlik ────────────────────────────
  var quietTimer = null, sawFirst = false;
  function started(url) {
    if (ignore(url)) { P.ignored++; return false; }
    if (!sawFirst) { sawFirst = true; post('xhr-first', { url: String(url).slice(0, 200) }); }
    P.inflight++;
    if (quietTimer) { clearTimeout(quietTimer); quietTimer = null; }
    return true;
  }
  function settled(url, ms, ok) {
    if (ignore(url)) return;
    P.inflight = Math.max(0, P.inflight - 1);
    post('xhr-end', { url: String(url).slice(0, 200), ms: Math.round(ms), ok: !!ok });
    if (P.inflight === 0) {
      if (quietTimer) clearTimeout(quietTimer);
      // Zincirleme istekler (A bitince B başlar) yanlış "sessiz" vermesin diye bekle.
      quietTimer = setTimeout(function () {
        if (P.inflight === 0) post('net-quiet', { since: Math.round(performance.now()) });
      }, QUIET_MS);
    }
  }

  var _fetch = window.fetch;
  if (_fetch) {
    window.fetch = function (input, init) {
      var url = (input && input.url) || input, s = performance.now();
      if (!started(url)) return _fetch.apply(this, arguments);
      return _fetch.apply(this, arguments).then(
        function (r) { settled(url, performance.now() - s, r.ok); return r; },
        function (e) { settled(url, performance.now() - s, false); throw e; }
      );
    };
  }

  var _open = XMLHttpRequest.prototype.open, _send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__u = u; return _open.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    var self = this, s = performance.now();
    if (started(self.__u)) {
      self.addEventListener('loadend', function () {
        settled(self.__u, performance.now() - s, self.status >= 200 && self.status < 400);
      });
    }
    return _send.apply(this, arguments);
  };

  // ── 3. DOM: anlamlı içerik belirdi mi ───────────────────────────────────
  var contentDone = false;
  function checkContent() {
    if (contentDone) return;
    var root = document.body;
    if (!root) return;
    if ((root.innerText || '').trim().length >= CONTENT_CHARS) {
      contentDone = true;
      post('first-content');
      requestAnimationFrame(function () {
        requestAnimationFrame(function () { post('painted'); });
      });
    }
  }
  new MutationObserver(checkContent).observe(document.documentElement,
    { childList: true, subtree: true, characterData: true });
  document.addEventListener('DOMContentLoaded', checkContent);

  // ── 4. Paint ve LCP ─────────────────────────────────────────────────────
  try {
    new PerformanceObserver(function (l) {
      l.getEntries().forEach(function (e) { post('paint', { name: e.name }); });
    }).observe({ type: 'paint', buffered: true });
  } catch (e) {}
  try {
    // ⚠️ LCP yalnızca Chromium'da var. WebKit'te bu blok sessizce atlanır.
    new PerformanceObserver(function (l) {
      var es = l.getEntries(); post('lcp', { size: es[es.length - 1].size });
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  } catch (e) {}

  // ── 5. SPA route değişimi ───────────────────────────────────────────────
  function onRoute(how) {
    contentDone = false; sawFirst = false;          // yeni ekran için sayaçları sıfırla
    post('route-change', { how: how, path: location.pathname + location.hash });
    setTimeout(checkContent, 0);
  }
  ['pushState', 'replaceState'].forEach(function (k) {
    var orig = history[k];
    history[k] = function () { var r = orig.apply(this, arguments); onRoute(k); return r; };
  });
  window.addEventListener('popstate', function () { onRoute('popstate'); });
  window.addEventListener('hashchange', function () { onRoute('hashchange'); });

  // ── 6. Native'in soracağı özet ──────────────────────────────────────────
  P.snapshot = function () {
    return { inflight: P.inflight, ignored: P.ignored,
             path: location.pathname + location.hash, marks: P.marks.length };
  };
})();
```

> 🚨 **`IGNORE` listesini keşif çıktısından doldurun.** Analitik/polling istekleri
> sayaca girerse `net-quiet` **hiç gelmez** ve Faz 5 sonsuza kadar spinner gösterir.
> Keşifte websocket/SSE gördüyseniz bu sezgiye **hiç güvenmeyin** (§00.3-E).

> ⚠️ **Prob, MFE'nin `fetch`'ini yamalar.** Bu bir davranış değişikliğidir:
> yamanın hata yutmadığından, `AbortController`'ı bozmadığından ve
> `Request` nesnesiyle çağrıldığında da çalıştığından emin olun. Prob'u
> **feature flag arkasına alın** ve kapatılabilir tutun.

---

## 1.5 Native tarafta kurulum

### iOS

```swift
import WebKit

final class ProbeHandler: NSObject, WKScriptMessageHandler {
    static let name = "probe"
    weak var sink: PhaseSink?
    let tag: String
    init(tag: String) { self.tag = tag }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let body = m.body as? [String: Any] else { return }
        let type = body["type"] as? String ?? "unknown"
        // ⚠️ Bilinmeyen tipleri YUTMAYIN. Yutarsanız mesajlar sessizce kaybolur
        //    ve "ölçüm gelmiyor" diye saatlerce hata ararsınız.
        sink?.received(tag: tag, phase: type, payload: body)
    }
}

// Kurulum — WebView YARATILMADAN ÖNCE (Faz 2.3)
func makeConfiguration(tag: String) -> WKWebViewConfiguration {
    let cfg = WKWebViewConfiguration()
    let ucc = WKUserContentController()
    ucc.add(ProbeHandler(tag: tag), name: ProbeHandler.name)

    let src = try! String(contentsOf: Bundle.main.url(forResource: "webview-probe",
                                                      withExtension: "js")!)
    ucc.addUserScript(WKUserScript(source: src,
                                   injectionTime: .atDocumentStart,
                                   forMainFrameOnly: true))
    cfg.userContentController = ucc
    return cfg
}
```

**Native fazlar — delegate'ten, prob olmadan:**

```swift
extension ScreenCoordinator: WKNavigationDelegate {
    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) {
        phase("native.nav-start")
    }
    // Redirect'i BURADA sayın — Faz 4'ün önceliği bu sayıya bağlı.
    func webView(_ w: WKWebView, didReceiveServerRedirectForProvisionalNavigation n: WKNavigation!) {
        redirectCount += 1
        phase("native.redirect", ["n": redirectCount, "url": w.url?.absoluteString ?? ""])
    }
    func webView(_ w: WKWebView, didCommit n: WKNavigation!) { phase("native.committed") }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!)  { phase("native.finished") }
}
```

### Android

```kotlin
class ProbeBridge(private val onPhase: (String, JSONObject) -> Unit) {
    @JavascriptInterface
    fun post(json: String) {
        val o = JSONObject(json)
        onPhase(o.optString("type", "unknown"), o)
    }
}

fun installProbe(webView: WebView, probeJs: String) {
    webView.addJavascriptInterface(ProbeBridge { phase, payload ->
        val ms = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
        if (ms >= 0) record(phase, ms, payload)
    }, "__ProbeBridge")

    if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
        WebViewCompat.addDocumentStartJavaScript(webView, probeJs, setOf(MFE_ORIGIN))
    } else {
        // ⚠️ Fallback yok sayılmamalı: bu cihazlarda ölçüm eksik olur.
        //    Raporlayın, sessizce geçmeyin.
        analytics.log("probe_document_start_unsupported")
    }
}
```

> ⚠️ `addJavascriptInterface` güvenlik yüzeyidir. Yalnızca **kendi origin'inize**
> yüklenen sayfalarda etkinleştirin (`addDocumentStartJavaScript`'te `setOf(origin)`
> zorunlu tutun) ve arayüzü minimum tutun — yukarıdaki `post` tek metottur.

---

## 1.6 ⚠️ Sezginin kalitesini ölçün — bu adım atlanamaz

`net-quiet` + `first-content`, MFE'nin gerçek "hazırım"ının **vekilidir**.
Vekilin ne kadar iyi olduğunu bilmeden Faz 5'i uygulayamazsınız.

**Yöntem:** 20-30 açılışı **ekran videosuyla** (60 fps) kaydedin ve karşılaştırın:

| Ölçü | Nasıl | Kabul |
|---|---|---|
| Sezgi **erken** tetikliyor | Video: içerik hâlâ görünmezken sinyal geldi | < %5 |
| Sezgi **geç** tetikliyor | Video: içerik göründükten sonra sinyal geldi | ortalama < 150 ms |
| Sezgi **hiç** tetiklemiyor | `net-quiet` gelmedi, zaman aşımına düşüldü | < %1 |

Erken tetikleme kullanıcıya **yarım ekran** gösterir; geç tetikleme **boşuna
bekletir**. Hangisine tahammülünüz olduğuna karar verin ve `QUIET_MS` /
`CONTENT_CHARS` değerlerini ona göre ayarlayın.

> **Ekranınızda hiç veri çekmeyen bir route varsa** (statik metin, onay ekranı)
> `net-quiet` anında gelir ve sezgi kusursuz çalışır. Referans ölçümde veri
> gerektirmeyen tek geçiş **8 ms** sürdü; diğerlerinin hepsi 198–578 ms.

---

## 1.7 Release build'de profiling

Debug build'in performans karakteristiği yanıltıcıdır. **Production'a yakın
build'i profilleyin.**

### Android
Chrome DevTools WebView'e tam yüzeyle bağlanır ve bu, manifest'teki `debuggable`
bayrağından **bağımsızdır** — yani release-configuration build profillenebilir.
Ama uygulamanız açıkça izin vermelidir:

```kotlin
if (FeatureFlags.webPerfProfiling) {
    WebView.setWebContentsDebuggingEnabled(true)
}
```

### iOS
iOS 16.4+ SDK'sına link edilmiş uygulamalarda `WKWebView` varsayılan olarak
inspect **edilemez**. `isInspectable = true` ile **TestFlight ve
release-configuration build'ler de** Safari Web Inspector'a açılabilir.

```swift
#if DEBUG
webView.isInspectable = true
#else
webView.isInspectable = FeatureFlags.webPerfProfiling
#endif
```

---

## 1.8 Production RUM

Lab ölçümü tek başına yetmez; p95'i gerçek cihaz/ağ dağılımında görmeniz gerekir.

Prob native'e raporladığı için **tüm zinciri native yazar** — web tarafında ayrı
bir analytics entegrasyonu gerekmez. Native, `t0`'dan `screen-ready`'ye kadar olan
faz tablosunu **tek bir event** olarak kendi analytics'ine yazar.

```swift
analytics.log("webview_screen_open", [
    "route": route, "strategy": strategy.rawValue,
    "t_committed": samples["native.committed"], "t_doc_start": samples["doc-start"],
    "t_route_change": samples["route-change"], "t_net_quiet": samples["net-quiet"],
    "t_screen_ready": samples["screen-ready"],
    "redirects": redirectCount, "xhr_count": xhrCount, "slowest_xhr_ms": slowestXhr,
    "device_class": DeviceClass.current.rawValue, "network": Reachability.current.rawValue,
    "timed_out": timedOut,
])
```

---

## 1.9 ⚠️ Cihaz sınıfına göre kırın

Ölçülmüş gerçek: aynı JS orta segment telefonda **3–4 kat**, 100 doların altındaki
cihazda **6 kattan fazla** sürüyor ([V8, 2019](https://v8.dev/blog/cost-of-javascript-2019)).

- Geliştirici telefonunda test etmeyin.
- Tek bir p50 sayısı, kullanıcılarınızın yarısının yaşadığını gizler.
- Metrikleri **cihaz sınıfı** ve **ağ koşulu** etiketiyle kırın.

---

## 1.10 Kabul kriterleri

Faz 2'ye geçmeden önce elinizde şunlar olmalı:

- [ ] Prob native kaynak ağacında, feature flag arkasında, documentStart'ta enjekte ediliyor
- [ ] `IGNORE` listesi keşif çıktısından dolduruldu
- [ ] Bilinmeyen mesaj tipleri **yutulmuyor**
- [ ] Redirect sayısı **native delegate'ten** sayılıyor
- [ ] Release-configuration build'de açılabilen profiling (flag'li)
- [ ] **p50 ve p95** faz tablosu, **cihaz sınıfı** ve **ağ koşulu** kırılımlı
- [ ] Cold start ve warm start senaryoları **ayrı** ölçülmüş
- [ ] **§1.6 sezgi kalitesi videoyla doğrulandı** ve sapma yazıldı

### İlk bakılacak üç sayı

1. **Redirect sayısı.** Sıfırdan farklıysa Faz 4 en yüksek önceliğinizdir.
2. **`native.committed` → `route-change` aralığı.** Büyükse Faz 3 çok kazandırır.
3. **`route-change` → `net-quiet` aralığı.** Baskınsa hiçbir WebView stratejisi
   sizi kurtarmaz; backend'e bakın (Faz 5.7).


---

# Faz 2 — Hızlı kazanımlar (native-only)

**Amaç:** Ölçüm beklemeden yapılabilecek, kanıt sınıfı en güçlü, maliyeti en düşük işler.
Hepsi ya RFC'ye ya da platform üreticisinin kendi API dokümanına dayanır.

**Süre:** 1-2 hafta · **Risk:** düşük · **Geri alınabilir:** evet

> **Ön koşul:** [`00-kesif.md`] (bu dosyada: Faz 0 — Keşif bölümü) onaylandı, [`01-olcum.md`] (bu dosyada: Faz 1 — Ölçüm bölümü) kuruldu.
>
> Bu fazdaki her kalem **native kod tabanında** yapılır. Tek istisna §2.1
> (cache header'ları): o sunucu/CDN tarafındadır ve native ekibin yetkisinde
> olmayabilir — bu yüzden burada yalnızca **native tarafta nasıl doğrulanacağı**
> anlatılır, talep metni [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü)'dedir.

---

## 2.1 Cache header'ları — ⚠️ native değil, ama native doğrular

Bu kalem **sunucu/CDN konfigürasyonudur**, MFE kaynak kodu değildir. Kapsam dışı
sayılsa bile **ölçüp raporlamak native ekibin işidir**, çünkü yanlış header
Faz 3'ün kazancını görünmez kılar.

### Native tarafta nasıl doğrulanır

Prob zaten Resource Timing'i görebiliyor (Faz 1.4). Isınmış bir WebView'de
sorun ve sonucu telemetriye yazın:

```swift
let js = "JSON.stringify(performance.getEntriesByType('resource')"
       + ".filter(r => r.initiatorType === 'script' || r.initiatorType === 'link')"
       + ".map(r => ({ u: r.name.split('/').pop(),"
       + "             kb: Math.round(r.transferSize/1024),"
       + "             cached: r.transferSize === 0 })))"

webView.evaluateJavaScript(js) { value, _ in
    // İKİNCİ açılışta cached:false olan her asset bir regresyondur.
    analytics.log("webview_asset_cache", ["payload": value as? String ?? ""])
}
```

| Gözlem | Anlamı | Yapılacak |
|---|---|---|
| İkinci açılışta hash'li asset `cached: false` | `immutable` yok veya `no-store` var | Talebi §09'a yazın |
| Her açılışta tüm bundle iniyor | Muhtemelen `no-store` | **Acil** — Faz 3 bile bunu kurtaramaz |
| `index.html` her seferinde 200 (304 değil) | `ETag` / revalidation yok | Talebi §09'a yazın |

### Doğru konfigürasyon (talep ederken bunu iletin)

```
hash'li asset'ler :  Cache-Control: public, max-age=31536000, immutable
index.html        :  Cache-Control: no-cache
                     ETag: "<build-hash>"
```

> 🚨 **`no-cache` ≠ `no-store`.** `no-cache` saklamayı yasaklamaz; her kullanımdan
> önce revalidation'a zorlar. İçerik değişmemişse sunucu `304` döner, body tekrar
> inmez — sadece 1 RTT ödenir. `no-store` kullanılıyorsa **tüm bundle her açılışta
> yeniden iner** ve bu, native tarafta yapabileceğiniz her şeyi gölgede bırakır.

### ⚠️ WebView cache'i app update'ten sağ çıkıyor mu — bilinmiyor

Header'lar doğru olsa bile, uygulama güncellemesinden sonra WebView'in HTTP
cache'inin korunup korunmadığı **doğrulanmamıştır**. Sürüm yükselttikten sonraki
ilk açılışı ayrı ölçün.

---

## 2.2 Cookie yazma sırası — sessiz hata

Her iki platformda da cookie yazma **asenkrondur.** `setCookie` çağırıp hemen
yüklerseniz **ilk istek cookie'siz çıkar**, 401 alır ve auth redirect zincirini
tetikler.

### iOS
Apple'ın dokümanı: completion handler *"asynchronously **after** the method
successfully stores the cookie"* çalışır.

```swift
let store = webView.configuration.websiteDataStore.httpCookieStore
let group = DispatchGroup()
for cookie in sessionCookies {
    group.enter()
    store.setCookie(cookie) { group.leave() }
}
group.notify(queue: .main) {
    webView.load(URLRequest(url: url))      // ✅ ancak burada yükle
}
```

### Android
Doküman birebir: *"**This method is asynchronous.** If a `ValueCallback` is provided,
`ValueCallback.onReceiveValue` will be called ... once the operation is complete."*

```kotlin
CookieManager.getInstance().setCookie(url, cookieValue) { ok ->
    if (ok) webView.loadUrl(url)             // ✅ callback'ten sonra
}
```

> ⚠️ Eski `setCookie(String, String)` overload'ı (API 1) **hiçbir tamamlanma sinyali
> vermez.** Callback'li sürümü kullanın.
>
> ⚠️ `Secure` attribute'u kullanıyorsanız doküman `url`'in **`https://`** olmasını
> şart koşar.

### `flush()` kritik yolda olmasın (Android)
Doküman: *"**This call will block the caller until it is done and may perform I/O.**"*
Ekran açılışında çağırmayın; uygulama arka plana giderken veya oturum kurulduktan
sonra çağırın.

---

## 2.3 User script WebView'den ÖNCE eklenmeli (iOS)

Apple'ın dokümanı: *"**Before you create the web view**, add this object to the
`WKUserContentController`..."* Sonradan eklemek o navigasyon için geç kalır.

```swift
let ucc = WKUserContentController()
ucc.addUserScript(WKUserScript(source: bootstrapJS,
                               injectionTime: .atDocumentStart,
                               forMainFrameOnly: true))
config.userContentController = ucc
let webView = WKWebView(frame: .zero, configuration: config)   // ✅ sonra yarat
```

---

## 2.4 Beyaz flash

### iOS (iOS 15+)
```swift
webView.isOpaque = false
webView.backgroundColor = .systemBackground
webView.underPageBackgroundColor = .systemBackground   // overscroll alanı
webView.scrollView.backgroundColor = .systemBackground
```
`underPageBackgroundColor`'ın varsayılanı sayfanın `<html>`/`<body>` arka planından
türetilir; tema renginize sabitleyin.

### Android
```kotlin
webView.setBackgroundColor(ContextCompat.getColor(context, R.color.screen_background))
```

### ⚠️ Web tarafındaki arka plan — kapsam dışı
Sayfanın `<html>`/`<body>` arka planı MFE'nin CSS'indedir ve ona dokunmuyoruz.
Native taraf bunu **üstünden kapatır**: `isOpaque = false` + tema renkli container
sayesinde kullanıcı, sayfa boyanana kadar MFE'nin beyazını değil sizin renginizi görür.

Tema uyumsuzluğu (koyu modda beyaz sayfa) görürseniz bu bir **web talebidir** —
[`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü)'ye yazın; native'de çözülmez.

> Bu, yükleme sırasındaki boş ekranı çözmez — onun için Faz 5 (reveal) veya
> Faz 6 (screenshot) gerekir. Bu sadece flash'ı kapatır.

---

## 2.5 Content process termination (iOS) — sıcak WebView tutacaksanız ZORUNLU

Apple: *"WebKit calls this method when the process for the specified web view
terminates **for any reason**."* Arka planda tutulan bir WebView'in content
process'i sistem tarafından öldürülebilir; WebView **boş beyaz bir dikdörtgene**
döner ve hiçbir şey yapmazsanız kullanıcı bunu görür.

```swift
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    analytics.log("webview_process_terminated", screen: currentScreen)
    // Sıcak havuzdaysa: bu instance'ı at, yenisini hazırla.
    pool.discard(webView)
    Task { await pool.prepareReplacement() }
}
```

**Bu handler Faz 3'ün ön koşuludur.** Sıcak WebView tutup bunu yazmamak,
kullanıcıya beyaz ekran göstermek demektir.

---

## 2.6 Android WebView pre-warm

Android'de WebView başlatma **implicit**'tir ve ilk tetiklendiğinde **tamamen
main/UI thread'de** çalışır — input'u bloklar, ANR riskini artırır.

`androidx.webkit` **1.16.0** ile stable olan resmî API:

```kotlin
// Application.onCreate()
override fun onCreate() {
    super.onCreate()
    if (WebViewFeature.isStartupFeatureSupported(
            this, WebViewFeature.STARTUP_FEATURE_SET_DIRECTORY_BASE_PATHS)) {
        val config = WebViewStartUpConfig.Builder(backgroundExecutor)
            .setShouldRunUiThreadStartUpTasks(false)
            .build()
        WebViewCompat.startUpWebView(config) { result ->
            // result.blockingStartUpLocations → UI thread'i nerede bloklandığını logla
        }
    }
}
```

> 🚨 **Faydası koşulludur.** Çağrıdan hemen sonra main thread'de bir WebView API'si
> kullanırsanız UI thread init'i beklemek zorunda kalır ve **kazanç tam sıfır olur.**
>
> İki kural birden geçerli:
> - **Erken tetikle** → `Application.onCreate()`
> - **Geç instantiate et** → WebView yaratmayı kritik yoldaki diğer UI işlerinden sonraya ertele
>
> `startUpWebView` çağırıp aynı frame'de `WebView(context)` yaratmak, API'yi hiç
> çağırmamakla aynı şeydir.

**iOS'ta bunun resmî karşılığı yoktur.** iOS'ta kazanç Faz 2'deki mimariden gelir.

---

## 2.7 `file://` kullanmayın (Android)

`file://` ve `data:` **opaque origin**'dir ve **`fetch()` / `XMLHttpRequest`
kullanamazlar.** `WebView.loadData()` içeride `data:` kullanır. Yani naif
"bundle'ı diske koy, diskten yükle" yaklaşımı **veri çeken bir React uygulaması
için çalışmaz.**

Doğrusu `WebViewAssetLoader`'dır (Faz 7'de).

---

## 2.8 Kabul kriterleri

- [ ] Hash'li asset'ler `immutable`, `index.html` `no-cache` + `ETag`
- [ ] Resource Timing'de tekrar açılışta `transferSize === 0`
- [ ] `setCookie` callback'i bekleniyor, sonra yükleniyor
- [ ] `CookieManager.flush()` kritik yolda değil
- [ ] `WKUserScript` WebView'den önce ekleniyor
- [ ] Beyaz flash kapalı (her iki platform)
- [ ] `webViewWebContentProcessDidTerminate` handler'ı var
- [ ] Android `startUpWebView` `Application.onCreate()`'te, instantiation ertelenmiş
- [ ] Hiçbir yerde `file://` ile bundle yüklenmiyor

**Beklenen etki:** Bunlar tek başına büyük bir açılış kazancı vermez —
**Faz 3'ün doğru çalışması için ön koşuldur** ve sessiz hataları kapatır.
Cache header'ları tekrar açılışlarda ağ fazını ciddi biçimde düşürür.


---

# Faz 3 — Sıcak WebView havuzu + native route swap

**Bu rehberin çekirdeği ve native-only kapsamın en zor kısmı.**
Referans ölçümde (MFE işbirliğiyle) JS zincirini **397 ms → 22 ms** düşürdü (18×).
Native-only'de bunun ne kadarını alabileceğiniz **ısınma hedefinizin ne kadar
sessiz olduğuna** bağlıdır — §3.2.

**Süre:** 3-6 hafta · **Risk:** orta · **Geri alınabilir:** evet (feature flag arkasında)

> **Ön koşul:** Keşifte route swap **fiilen test edildi** ([`00-kesif.md`] (bu dosyada: Faz 0 — Keşif bölümü) §0.3-A).
> Test edilmediyse buraya geçmeyin.

---

## 3.1 Fikir

Bugün olan:
```
kullanıcı dokunur → WebView yarat → doküman yükle → JS indir → parse → React boot → route → veri
                    └──────────── hepsi kullanıcı beklerken ────────────┘
```

Olması gereken:
```
UYGULAMA AÇILIŞI (kullanıcı beklemiyor)
  → gizli WebView yarat → ısınma hedefini yükle → JS indir → parse → React boot → BEKLE

kullanıcı dokunur
  → WebView'i göster → enjekte edilen sürücü: route'u değiştir → veri
     └── sayfa YÜKLENMİYOR. React zaten ayakta. ──┘
```

**MFE işbirliği yapsaydı** bunun için yan etkisiz bir `/warmup` route'u olurdu.
Yok. O yüzden native, **var olan bir route'u ısınma hedefi olarak seçmek** ve
**yan etkilerini kendi katmanında bastırmak** zorunda.

---

## 3.2 Isınma hedefi seçimi — bu fazın en önemli kararı

Dört seçenek var. **Keşif çıktınız hangisinin mümkün olduğunu söyler.**

| # | Hedef | JS boot kazancı | Yan etki riski | Ne zaman |
|---|---|---|---|---|
| **A** | `about:blank` | ❌ yok (sadece WebView/process maliyeti kalkar) | **sıfır** | Her zaman güvenli taban. Ölçülen: **−13%** |
| **B** | Mevcut **veri çekmeyen** route (yasal metin, "hakkında", onay ekranı, 404) | ✅ tam | **düşük** | Keşif §0.5-5'te böyle bir route bulunduysa — **tercih edilen** |
| **C** | Gerçek entry route + native susturma (§3.3) | ✅ tam | **orta-yüksek** | B yoksa ve susturma doğrulandıysa |
| **D** | MFE'ye `/warmup` eklenmesi | ✅ tam | sıfır | **Kapsam dışı** → [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü) |

### 🚨 A ile B/C arasındaki fark neden bu kadar büyük

`about:blank`, JS bundle'ını **hiç indirmez ve çalıştırmaz**. Kazandırdığı tek şey
WKWebView/WebView nesnesinin ve içerik process'inin önceden var olmasıdır.
Referans ölçümde bu **−13%**; `/warmup` ile JS'i de önden çalıştırmak **−37%**.

**Yani bu fazın gerçek kazancı B veya C'yi uygulayabilmenize bağlıdır.**
B'yi bulamadıysanız ve C'nin riskini alamıyorsanız, native-only tavanınız
−13% ile Faz 6 (kalıcı WebView) arasındadır — bunu kullanıcıya **açıkça söyleyin.**

### B seçeneğini nasıl bulursunuz

Keşifte her route'u açıp Network panelini izleyin. Aradığınız route:

- [ ] Hiçbir `/api/*` çağrısı yapmıyor
- [ ] Analitik event'i **ya göndermiyor ya da** gönderdiği event iş metriklerinizi bozmuyor
- [ ] Auth redirect tetiklemiyor (ya da tetikliyorsa bu **istediğiniz** şey — Faz 4)
- [ ] Hızlı mount oluyor

> ⚠️ **Analitik hâlâ bir sorun olabilir.** Isınma hedefi bir "ekran görüntüleme"
> event'i gönderiyorsa, kullanıcı o ekranı hiç görmeden görüntülenmiş sayılır.
> §3.3'teki susturma bunu ağ seviyesinde keser; ama uygulama event'i **kuyruğa
> alıp sonra gönderiyorsa** kesilmez. Keşif §0.3-G'de bunu tespit edin.

---

## 3.3 Isınmayı susturma — native katmanda

Isınma sırasında analitiği (ve gerekiyorsa API'yi) **ağ seviyesinde** engelleyin,
WebView gösterilmeden hemen önce engeli kaldırın.

### iOS — `WKContentRuleList`

```swift
import WebKit

enum WarmupSilencer {
    /// Keşif §0.3-G'de tespit ettiğiniz host'ları buraya yazın.
    static let rulesJSON = """
    [
      { "trigger": { "url-filter": ".*", "if-domain": ["*analytics.example.com",
                                                       "*telemetry.example.com"] },
        "action": { "type": "block" } }
    ]
    """

    static func compile() async -> WKContentRuleList? {
        await withCheckedContinuation { c in
            WKContentRuleListStore.default()?.compileContentRuleList(
                forIdentifier: "warmup-silencer",
                encodedContentRuleList: rulesJSON
            ) { list, _ in c.resume(returning: list) }
        }
    }
}

// Isınırken ekle
if let list = await WarmupSilencer.compile() {
    webView.configuration.userContentController.add(list)
    silencer = list
}

// Kullanıcıya göstermeden HEMEN ÖNCE kaldır
if let list = silencer {
    webView.configuration.userContentController.remove(list)
    silencer = nil
}
```

### Android — `shouldInterceptRequest`

```kotlin
class WarmupAwareClient(private val isWarming: () -> Boolean) : WebViewClientCompat() {
    private val blocked = listOf("analytics.example.com", "telemetry.example.com")

    override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest):
        WebResourceResponse? {
        if (isWarming() && blocked.any { req.url.host?.endsWith(it) == true }) {
            // Boş 204 — istek ağa hiç çıkmaz.
            return WebResourceResponse("text/plain", "utf-8", 204, "No Content",
                                       emptyMap(), ByteArrayInputStream(ByteArray(0)))
        }
        return null
    }
}
```

> ⚠️ Keşifte zaten bir `WebViewClient` alt sınıfı bulduysanız bu mantığı **onun
> içine** ekleyin, ikinci bir client kurmayın.
>
> 🚨 `shouldInterceptRequest` kullanıyorsanız Android speculative **prefetch**
> API'si fiilen devre dışı kalır (Faz 7.4). İkisi birlikte kullanılamaz.

### 🚨 Susturmanın üç sınırı — dürüstçe

| Sınır | Sonuç |
|---|---|
| **Kuyruklu analitik** | Uygulama event'i `sendBeacon`/kuyrukla sonra gönderiyorsa engel işe yaramaz; event daha sonra gider |
| **API engellenirse hata state'i** | Ekran "yüklenemedi" durumuna düşer; route swap sonrası bu state'te kalabilir (bazı veri katmanları hatayı cache'ler) |
| **Uygulama içi sayaçlar** | `localStorage`'a yazılan "kaç kez açıldı" gibi sayaçlar ağdan bağımsız artar |

**Bu yüzden B seçeneği (veri çekmeyen route) C'den her zaman daha iyidir.**
C'yi seçtiyseniz, engeli kaldırdıktan sonra hedef route'a geçişin **gerçekten
taze veri çektiğini** doğrulayın (§3.10).

---

## 3.4 Native route swap — enjekte edilen sürücü

MFE bir `window.__mfe.navigate()` köprüsü sunmuyor. Native kendi sürücüsünü
enjekte eder — **prob ile aynı documentStart script'inin içine** koyun.

```js
// webview-probe.js'in sonuna eklenir.
// MFE'nin router'ını DIŞARIDAN sürer. Sayfa yeniden yüklenmez.
window.__nativeRoute = {
  /** Keşif §0.3-A'da tespit edilen mod: 'history' | 'hash' */
  mode: 'history',

  go: function (path) {
    var before = location.pathname + location.hash;
    if (this.mode === 'hash') {
      // Hash router: en güvenilir yol. hashchange doğal olarak tetiklenir.
      if (location.hash !== '#' + path) location.hash = path;
      else window.dispatchEvent(new HashChangeEvent('hashchange'));
    } else {
      history.pushState({}, '', path);
      // Router'ın dinlediği olay bu. Sentetik dispatch ŞARTTIR —
      // pushState tek başına hiçbir olay üretmez.
      window.dispatchEvent(new PopStateEvent('popstate', { state: history.state }));
    }
    window.__probe && window.__probe.post('native-route-go', { from: before, to: path });
    return before;
  },

  /** Native, swap'ın gerçekten işe yaradığını doğrulamak için sorar. */
  current: function () { return location.pathname + location.hash; },
}
```

```swift
// iOS — çağrı
webView.evaluateJavaScript("window.__nativeRoute.go('\(route)')", completionHandler: nil)
```
```kotlin
// Android — çağrı
webView.evaluateJavascript("window.__nativeRoute.go('$route')", null)
```

> ⚠️ **`evaluateJavaScript`'i Swift'te `async` bağlamda çağırırsanız** derleyici
> `async throws` overload'ını seçer ve çağrı **bloklar**. Ölçümü bozar. Açıkça
> `completionHandler:` varyantını kullanın.

### 🚨 Route swap'ın çalıştığını varsaymayın — doğrulayın

Sentetik `popstate` her router sürümünde işe yaramaz. Bazı router'lar
`history.state` içinde kendi indekslerini tutar ve dışarıdan gelen olayı yok sayar.

**Runtime doğrulama koyun ve başarısızlıkta tam yüklemeye düşün:**

```swift
func swapRoute(_ wv: WKWebView, to route: String) {
    wv.evaluateJavaScript("window.__nativeRoute.go('\(route)')", completionHandler: nil)

    // 400 ms içinde route değişmediyse swap tutmadı → normal yüklemeye düş.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        wv.evaluateJavaScript("window.__nativeRoute.current()") { value, _ in
            let ok = (value as? String)?.contains(route) == true
            analytics.log("webview_route_swap", ["route": route, "ok": ok])
            if !ok {
                // Fallback: kazancı kaybederiz ama kullanıcı doğru ekranı görür.
                wv.load(URLRequest(url: self.url(for: route)))
            }
        }
    }
}
```

**Bu fallback zorunludur.** Onsuz, router uyumsuzluğu sizi kullanıcıya
**yanlış ekran** göstermeye götürür — yavaş ekrandan çok daha kötü bir hata.

---

## 3.5 iOS — sıcak WebView havuzu

```swift
import WebKit

@MainActor
final class WarmWebViewPool {
    private var warm: WKWebView?
    private var isReady = false
    private var silencer: WKContentRuleList?
    private let config: AppConfig

    // MARK: Hazırlık — uygulama açılışında çağrılır

    func prepare() async {
        teardown()
        let wv = makeWebView()
        attachOffscreen(wv)                    // hierarchy İÇİNDE ama görünmez
        warm = wv

        if let list = await WarmupSilencer.compile() {       // §3.3
            wv.configuration.userContentController.add(list)
            silencer = list
        }
        wv.load(URLRequest(url: config.warmupTargetURL))     // §3.2'deki A/B/C
        isReady = await waitUntilWarm(wv, timeout: 15)
    }

    /// "Isındı" tanımı — MFE bize söylemiyor, prob'dan çıkarıyoruz.
    /// A seçeneğinde (about:blank) yalnızca didFinish beklenir.
    /// B/C'de: doc-start geldi VE ağ sustu.
    private func waitUntilWarm(_ wv: WKWebView, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.sawDocStart(for: wv) && probe.sawNetQuiet(for: wv) { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        analytics.log("webview_warmup_timeout")
        return false
    }

    // MARK: Kullanım — kullanıcı dokunduğunda

    /// Sıcak instance'ı verir ve havuzu boşaltır.
    /// Hazır değilse hazırlanmasını bekler (ilk açılış senaryosu).
    func take() async -> WKWebView {
        if !isReady { await prepare() }
        // Susturmayı KALDIR — artık gerçek ekran açılıyor.
        if let list = silencer {
            warm?.configuration.userContentController.remove(list)
            silencer = nil
        }
        defer { warm = nil; isReady = false }
        return warm ?? makeWebView()
    }

    /// Ekran kapandıktan sonra bir sonraki için yeniden ısıt.
    func replenish() async { await prepare() }

    // MARK: Detaylar

    private func makeWebView() -> WKWebView {
        let c = makeConfiguration(tag: "pool")   // Faz 1.5: prob + sürücü burada enjekte edilir
        let wv = WKWebView(frame: UIScreen.main.bounds, configuration: c)
        wv.navigationDelegate = self             // redirect sayımı + process termination
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        wv.underPageBackgroundColor = .systemBackground
        return wv
    }

    /// Görünmez ama hierarchy İÇİNDE.
    ///
    /// ⚠️ Hierarchy dışındaki bir WKWebView'in gerçekten render edip etmediği
    /// Apple tarafından dokümante edilmemiştir. Ekranda olmayan ama hierarchy'de
    /// olan bir view render eder; tamamen detached olan etmeyebilir.
    /// Bu anahtarı açık/kapalı ÖLÇÜN — Faz 3'ün temel varsayımıdır.
    private func attachOffscreen(_ wv: WKWebView) {
        guard let win = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        wv.frame = CGRect(x: -win.bounds.width * 2, y: 0,
                          width: win.bounds.width, height: win.bounds.height)
        wv.isHidden = false
        wv.alpha = 1
        win.insertSubview(wv, at: 0)             // en altta, hiçbir şeyi kapatmaz
    }

    private func teardown() {
        warm?.configuration.userContentController
            .removeScriptMessageHandler(forName: ProbeHandler.name)
        warm?.removeFromSuperview()
        warm = nil; isReady = false; silencer = nil
    }
}
```

### Ekranı açma

```swift
@MainActor
func openWebScreen(route: String) async {
    let t0 = CACurrentMediaTime()            // ÖLÇÜM: kullanıcının dokunduğu an

    let wv = await pool.take()               // susturma burada kalkar
    wv.removeFromSuperview()
    present(wv)                              // container'a koy (Faz 5: opacity 0 ile)

    swapRoute(wv, to: route)                 // §3.4 — doğrulama + fallback dahil

    Task { await pool.replenish() }          // bir sonraki açılış için arka planda ısıt
}
```

---

## 3.6 Android — sıcak WebView havuzu

```kotlin
class WarmWebViewPool(
    private val app: Application,
    private val config: AppConfig,
) {
    private var warm: WebView? = null
    private var ready = false
    @Volatile var isWarming = false
        private set

    suspend fun prepare() = withContext(Dispatchers.Main) {
        teardown()
        isWarming = true                       // WarmupAwareClient bunu okur (§3.3)
        val wv = makeWebView()
        attachOffscreen(wv)
        warm = wv
        wv.loadUrl(config.warmupTargetUrl)
        ready = awaitWarm(15_000)
    }

    suspend fun take(): WebView = withContext(Dispatchers.Main) {
        if (!ready) prepare()
        isWarming = false                      // susturmayı kaldır
        val wv = warm ?: makeWebView()
        warm = null; ready = false
        wv
    }

    private fun makeWebView(): WebView = WebView(app).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        setBackgroundColor(ContextCompat.getColor(app, R.color.screen_background))
        installProbe(this, probeJs)            // Faz 1.5
        webViewClient = WarmupAwareClient { isWarming }
    }

    /**
     * Hierarchy içinde ama ekran dışında. decor view'a 1x1 eklemek yaygın yöntemdir.
     */
    private fun attachOffscreen(wv: WebView) {
        val root = currentActivity()?.window?.decorView as? ViewGroup ?: return
        root.addView(wv, ViewGroup.LayoutParams(1, 1))
        wv.x = -10_000f
    }

    private fun teardown() {
        warm?.let { (it.parent as? ViewGroup)?.removeView(it); it.destroy() }
        warm = null; ready = false; isWarming = false
    }
}
```

```kotlin
suspend fun openWebScreen(route: String) {
    val t0 = SystemClock.elapsedRealtimeNanos()
    val wv = pool.take()
    present(wv)
    swapRoute(wv, route)                       // §3.4 doğrulama + fallback
    scope.launch { pool.prepare() }
}
```

---

## 3.7 Ne zaman ısıtmalı

| An | Yapılacak |
|---|---|
| Uygulama açılışı (`didFinishLaunching` / `Application.onCreate`) | İlk sıcak instance'ı hazırla |
| Bir web ekranı kapandığında | Yeniden ısıt (`replenish`) |
| Uygulama arka plana gittiğinde | Bellek baskısı yüksekse bırakmayı değerlendir |
| Öne döndüğünde | Sıcak instance hâlâ canlı mı kontrol et, değilse yeniden kur |
| `webContentProcessDidTerminate` | At, yenisini hazırla (Faz 2.5) |

> ⚠️ **Android'de `startUpWebView` ile çakışmayın.** Faz 2.6'daki kural hâlâ
> geçerli: `Application.onCreate`'te `startUpWebView` çağırıp **aynı frame'de**
> havuzun WebView'ini yaratırsanız kazanç tam sıfır olur. Havuz hazırlığını
> bir sonraki frame'e veya ilk idle'a erteleyin.

> **Kaç instance tutmalı?** Referans uygulama **tek** instance tuttu. Havuz boyutunu
> artırmak ard arda ekran açmayı hızlandırır ama bellek ve jetsam riskini büyütür.
> Optimal değeri **ölçülmemiştir** — keşif §0.5-2'deki bellek bütçesiyle deneyin.

---

## 3.8 Reset problemi — havuz modelinde yoktur, bu bir avantajdır

MFE işbirliği yapsaydı, ekran kapanınca `window.__mfe.reset()` çağırıp React
ağacını temizlerdiniz. Yapmıyor ve native, React state'ini dışarıdan güvenilir
biçimde temizleyemez.

**Havuz modelinde buna gerek yok:** kullanılan WebView **atılır**, yenisi sıfırdan
ısıtılır. Kirlenmiş state ile hiç karşılaşmazsınız.

> 🚨 **Bu, Faz 6'ya (kalıcı WebView) geçerseniz değişir.** Orada aynı WebView
> yaşamaya devam eder ve state kirlenmesi gerçek bir sorundur —
> [`06-kalici-webview.md`] (bu dosyada: Faz 6 — Kalıcı WebView bölümü) §6.6'ya bakın.

Bedeli: her ekran açılışından sonra ısınmayı **yeniden ödersiniz**. Kullanıcı
ard arda hızlı ekran açarsa ikinci açılış sıcak olmayabilir. Bunu ölçün:
**"ard arda 5 ekran"** senaryosu (Faz 6.2).

---

## 3.9 🚨 Bu fazı sessizce öldüren hatalar

| Hata | Sonuç |
|---|---|
| Route swap'ın çalıştığını **doğrulamamak** | Kullanıcı **yanlış ekranı** görür — en kötü hata |
| Swap fallback'i yazmamak | Router uyumsuzluğunda ekran hiç değişmez |
| Sıcak WebView hierarchy dışında | Render etmeyebilir; "ısıttım ama fark yok" |
| `evaluateJavaScript`'in async overload'ı (Swift) | Çağrı bloklar, ölçüm bozulur |
| Ekran kapandıktan sonra yeniden ısıtmamak | İkinci açılış cold baseline'a döner |
| Susturmayı göstermeden önce kaldırmamak | Gerçek ekran veri çekemez, boş kalır |
| Susturmayı hiç kurmamak (C seçeneğinde) | Görüntülenmemiş ekranlar analitiğinizi bozar |
| `about:blank` ile ısıtıp `/warmup` kazancı beklemek | JS hiç çalışmadı; kazanç −13% ile sınırlı |
| Process termination handler yok (Faz 2.5) | Kullanıcı beyaz dikdörtgen görür |
| Isınma bitmeden ölçüm başlatmak | Kazanç ısınma süresiyle maskelenir |
| `startUpWebView` ile aynı frame'de havuz kurmak | Android'de kazanç tam sıfır |

---

## 3.10 Doğrulama

### Isınma gerçekten sessiz mi?
Uygulamayı açın, **hiçbir ekrana dokunmayın**, 60 sn bekleyin. Sunucu/analitik
tarafında sayın:

```
beklenen:  doküman yüklemesi > 0      (JS ayağa kalktı — B/C seçeneğinde)
           analitik event     = 0      ← ZORUNLU
           veri isteği        = 0      ← B seçeneğinde zorunlu, C'de susturmayla
```

> Bu ölçümü **backend/analitik ekibiyle birlikte** yapın. Kendi cihazınızdaki
> Network paneli, kuyruğa alınıp sonra gönderilen event'i göstermez.

### Faz tablosunda ne görmelisiniz
```
native.committed  → yok        (sayfa yeniden yüklenmedi)
doc-start         → yok        (prob zaten çalışmıştı)
native-route-go   → ~5-20 ms
route-change      → ~20-80 ms  ← buraya kadar olan her şey artık neredeyse bedava
net-quiet         → API'nize bağlı
```

`doc-start` sütunu **boşsa doğru çalışıyor.** Doluysa sayfa yeniden yükleniyor
demektir — swap fallback'i devreye girmiş olabilir, `webview_route_swap` telemetrisine bakın.

### Swap başarı oranı — production sağlık metriği
`webview_route_swap.ok` oranı **%99'un altındaysa** bu fazın kazancı yoktur;
router uyumluluğunu yeniden inceleyin.

---

## 3.11 Kabul kriterleri

- [ ] Isınma hedefi seçildi (A/B/C) ve gerekçesi keşif raporuna dayandırıldı
- [ ] C seçildiyse susturma kuruldu ve **kaldırma** yolu test edildi
- [ ] Isınmanın sessizliği backend/analitik tarafında **doğrulandı**
- [ ] `window.__nativeRoute` sürücüsü prob ile aynı script'te enjekte ediliyor
- [ ] Route swap **runtime doğrulaması** ve **tam yükleme fallback'i** var
- [ ] `webview_route_swap.ok` telemetriye yazılıyor
- [ ] Sıcak instance uygulama açılışında hazırlanıyor, ekran kapanınca yeniden ısıtılıyor
- [ ] Sıcak WebView hierarchy içinde (ve bu **ölçümle** doğrulandı)
- [ ] Process termination handler'ı sıcak instance'ı değiştiriyor
- [ ] Faz tablosunda `doc-start` boş
- [ ] Android: `startUpWebView` ile havuz kurulumu aynı frame'de değil
- [ ] Feature flag arkasında, açıp kapatılabiliyor

**Beklenen etki — dürüst aralık:**

| Isınma hedefi | Beklenen |
|---|---|
| A (`about:blank`) | **≈ −13%** (ölçüldü) |
| B (veri çekmeyen mevcut route) | −13% ile −37% arası. **Referans ölçümde bu varyant ayrıca ölçülmedi** — kendi sayınızı üretin |
| C (entry route + susturma) | B ile aynı tavan, ama yan etki riski taşır |

Gerçek etkisi sizin veri bekleme payınıza bağlıdır — Faz 1 tablonuz söyler.


---

# Faz 4 — Auth redirect zincirini kritik yoldan çıkarma (native-only)

**Ne zaman:** Faz 1 tablonuzda `redirectEnd − redirectStart` sıfırdan farklıysa.
**Bu, sektörde yayımlanmış tek gerçek vaka çalışmasının kök nedeniydi.**

**Süre:** 2-4 hafta · **Risk:** orta (güvenlik ödünleri var) · **Geri alınabilir:** evet

> **Native-only notu:** Bu fazın cookie tabanlı kısmı MFE'ye dokunmadan çalışır —
> cookie'yi native yazar, MFE'nin mevcut `fetch`'i onu kendiliğinden gönderir.
> Token enjeksiyonu ve `window.__PRELOADED__` okuma **kapsam dışıdır** (§4.3, §4.4).

---

## 4.1 Neden en çok gözden kaçan maliyet

Shopify'ın mühendislik ekibi ~600 ekranlı uygulamalarında şunu buldu:

> *"It turned out that loading a new web page was slow mainly due to the authentication
> process. **Each WebView had to bounce through several redirects just to authenticate**,
> causing noticeable delays."*

Çözümleri:

> *"...**preloading and authenticating WebViews in the background** as soon as the app opens."*

Yayımlanmış sonuç: **P75 6 sn → 1.4 sn (~6×)**.
([Shopify Engineering — Mobile Bridge](https://shopify.engineering/mobilebridge-native-webviews))

> ⚠️ Bu Shopify'ın ölçümüdür, sizinki değil. Ve bir **paket sonucudur** —
> preloading, arka planda authentication, havuzlama ve WebView taşıma birlikte
> uygulandı; hangi kazancın hangisine ait olduğu yayımlanmadı.

Bu maliyet gözden kaçar çünkü:
- Faz olarak **ağ** görünür, ama backend dashboard'unda API'ler hızlıdır
- Web ekibi *"bundle'ımız küçük"* der — haklıdır
- Native ekip *"WebView'i hemen açıyoruz"* der — o da haklıdır
- **Kimse redirect zincirine bakmaz**

---

## 4.2 Önce ölçün — native tarafta

Redirect'i sayfadan değil **navigation delegate'ten** sayın (Faz 1.5). Böylece
prob enjekte edilemeyen durumlarda bile sayı elinizde olur ve production'a yazılır.

```swift
func webView(_ w: WKWebView, didReceiveServerRedirectForProvisionalNavigation n: WKNavigation!) {
    redirectCount += 1
}
```

Prob'un `load` mark'ı bunu doğrular:

```js
// webview-probe.js zaten gönderiyor (Faz 1.4)
{ type: 'load', redirectMs: …, ttfb: … }
```

İkisini karşılaştırın: delegate sayısı > 0 ama `redirectMs` ≈ 0 ise redirect'ler
Navigation Timing'e yansımıyordur (cross-origin zincir) — **delegate sayısına güvenin.**

Mobil şebekede **her redirect bir tam gidiş-dönüştür**; 3-4 redirect rahatlıkla
1 saniye eder.

---

## 4.3 Desen: oturumu native'den önden taşı

```
UYGULAMA AÇILIŞI
  ├─ native: token al / yenile           (kullanıcı beklemiyor)
  ├─ native: cookie'leri yaz             (callback BEKLENEREK — Faz 2.2)
  └─ native: sıcak WebView'i ısınma hedefine yükle
             └─ auth zinciri BURADA ödenir, arka planda, görünmeden

KULLANICI DOKUNUR
  ├─ WebView zaten authenticated   → redirect zinciri YOK
  └─ İlk API çağrısı cookie'yle çıkar → 401 + retry YOK
```

**Native-only'de işleyen tek taşıyıcı cookie'dir.** Sebebi §4.3 sonundaki notta.

### iOS

```swift
// Cookie — YAZMA TAMAMLANANA KADAR bekle (Faz 2.2)
func preauthenticate(_ wv: WKWebView, session: Session) async {
    let store = wv.configuration.websiteDataStore.httpCookieStore
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        let group = DispatchGroup()
        for cookie in session.cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { c.resume() }
    }
}
```

> ⚠️ Bunu **ısınma yüklemesinden önce** çağırın. Isınma hedefi cookie'siz
> yüklenirse auth zincirini ısınmada ödemek yerine kullanıcı dokunduğunda
> ödersiniz ve bu fazın tamamı boşa gider.

### Android

```kotlin
suspend fun preauthenticate(session: Session) = suspendCoroutine { cont ->
    val cm = CookieManager.getInstance()
    var remaining = session.cookies.size
    if (remaining == 0) cont.resume(Unit)
    session.cookies.forEach { c ->
        cm.setCookie(c.url, c.value) {
            if (--remaining == 0) cont.resume(Unit)
        }
    }
}
```


---

### ⚠️ Web tarafı — burada duruyoruz

MFE'nin `window.__SESSION__` gibi bir global'i okuması **işbirliği gerektirir**
ve kapsam dışıdır. Native-only'de işleyen mekanizma **cookie**'dir:

> Cookie'yi native yazar; MFE'nin mevcut `fetch`'i onu **kendiliğinden** gönderir.
> MFE'ye tek satır yazılmaz.

Bunun çalışması için iki koşul:

| Koşul | Nasıl doğrulanır |
|---|---|
| MFE, API'ye **credentials ile** istek atıyor olmalı | Keşifte Network panelinde istek header'larında `Cookie` görünüyor mu? |
| API origin'i, cookie'nin domain/path kapsamında olmalı | `Set-Cookie` domain'i ile API host'unu karşılaştırın |

`fetch(..., { credentials: 'omit' })` kullanan bir MFE cookie göndermez ve bu
desen onda **çalışmaz**. O durumda tek yol token enjeksiyonudur → kapsam dışı,
[`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü).

> Prob'un `fetch` yamasıyla `credentials`'ı zorlamayı **denemeyin**. MFE'nin ağ
> semantiğini native'den değiştirmek, teşhis edilmesi çok zor hatalar üretir ve
> bu rehberin kapsam sınırını aşar.

---

## 4.4 İlk veriyi önden çekmek — platform asimetrisi

MFE işbirliği yapsaydı native, veriyi `window.__PRELOADED__`'a enjekte eder,
MFE onu okurdu. Yapmıyor. Native-only'de tek yol **isteği araya girip önceden
alınmış cevabı servis etmektir** ve bu yalnızca bir platformda mümkün:

| Platform | Mümkün mü | Mekanizma |
|---|---|---|
| **Android** | ✅ | `shouldInterceptRequest` — isteği yakalar, hazır cevabı döner |
| **iOS** | ❌ | `https` için handler kaydı **imkânsız** (`invalidArgumentException`); `NSURLProtocol` WKWebView'de instantiate edilmez (Faz 7.2) |

### Android — önden çekilmiş cevabı servis etmek

```kotlin
class PreloadingClient(
    private val cache: PreloadCache,
) : WebViewClientCompat() {

    override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest):
        WebResourceResponse? {
        if (req.method != "GET") return null
        val hit = cache.take(req.url.toString()) ?: return null   // tek kullanımlık

        return WebResourceResponse(
            "application/json", "utf-8", 200, "OK",
            // Sayfa ile aynı origin olduğu için CORS header'ı gerekmez.
            mapOf("Cache-Control" to "no-store"),
            ByteArrayInputStream(hit.body),
        )
    }
}
```

Native, uygulama açılışında (veya kullanıcı listeye dokunmadan hemen önce)
ekranın ilk payload'ını kendi HTTP istemcisiyle çeker ve `PreloadCache`'e koyar.

### 🚨 Bu tekniğin dört tuzağı

| Tuzak | Önlem |
|---|---|
| **Bayatlık** | Kısa TTL koyun (ör. 30 sn) ve süresi geçmişse `null` dönüp normal isteğe bırakın |
| **Tek kullanımlık olmalı** | `take()` cache'ten siler; yoksa ekran her açılışta aynı bayat veriyi görür |
| **Prefetch API'siyle çakışır** | `shouldInterceptRequest` varken Android speculative prefetch fiilen devre dışı (Faz 7.4) |
| **Header/auth farkı** | Native istemcinizin gönderdiği auth ile WebView'inkinin **aynı kullanıcıya** ait olduğundan emin olun; değilse veri sızıntısı olur |

> ⚠️ **Bu, platformlar arası davranış farkı yaratır.** iOS bu kazancı alamaz.
> A/B ve telemetriyi platform kırılımlı okuyun, yoksa "Android neden daha hızlı"
> sorusunu yanlış yanıtlarsınız.

### iOS'ta karşılığı ne

Yok. iOS'ta veri beklemesini kısaltmanın native-only yolu bulunmuyor. iOS'ta
kazanç **mimariden** gelmek zorunda (Faz 3 ve Faz 6) ve veri payı olduğu gibi
kalır. Bunu hedef belirlerken kabul edin — Faz 1 tablonuzda iOS'un
`route-change → net-quiet` kalemi değişmeyecektir.

---

## 4.5 Güvenlik ödünleri — dürüstçe

Bearer token'ı web içeriğine enjekte etmek bir risktir: WebView içindeki her script
ve yüklenen her üçüncü taraf kaynak ona erişebilir.

| Önlem | Neden |
|---|---|
| **Kısa ömürlü, dar kapsamlı** token | Sızarsa hasar penceresi küçük |
| **Refresh token'ı ASLA enjekte etme** | Kalıcı erişim demektir |
| WebView'de **CSP** uygula | Üçüncü taraf script yüklenmesin |
| `forMainFrameOnly: true` | iframe'lere sızmasın |
| **`HttpOnly` cookie** — native-only'de zaten tek yol budur | JS erişemez, aynı redirect'siz akışı verir |
| Origin allowlist | `addDocumentStartJavaScript`'te origin kısıtlayın (prob enjeksiyonu için de geçerli) |

> **OAuth için ayrı kural:** [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)
> (OAuth 2.0 for Native Apps), yetkilendirme akışının gömülü WebView'de değil
> **harici user-agent**'ta (iOS'ta `ASWebAuthenticationSession`, Android'de
> Custom Tabs) yapılmasını öngörür.
>
> Bu fazdaki desen **zaten kurulmuş bir oturumu** WebView'e taşımakla ilgilidir —
> kullanıcıyı WebView içinde login ettirmekle değil. İkisini karıştırmayın.

---

## 4.6 ⚠️ Önemli: sıcak WebView zaten auth'u hallediyor olabilir

Referans ölçümde **preauth varyantı, sade sıcak varyanttan anlamlı biçimde iyi
çıkmadı** (522 vs 565 ms; p95'i daha da kötüydü).

Sebep: **auth zinciri zaten **ısınma hedefi yüklenirken**, uygulama açılışında ödeniyordu.**
Dokunma anında ikisi de sıfır redirect yapıyordu.

Preauth'un gerçek değeri:
- **Sıcak instance'ın ne kadar çabuk hazır olduğunda** (ısınma süresini kısaltır)
- **Cold fallback senaryosunda** (sıcak instance hazır değilken açılan ilk ekran)
- **Oturum her açılışta sıfırdan kuruluyorsa** (cookie kalıcı değilse)

**Kendi ölçümünüzde bu ikisini ayırın:** cache/cookie'yi her koşudan önce temizleyen
bir senaryo koşmadan preauth'un değerini göremezsiniz.

---

## 4.7 Doğrulanamayan noktalar

Araştırmada şunlar için doğrulanmış kaynak bulunamadı — **test edin, varsaymayın:**

- İlk `URLRequest`'teki **custom header'ların sonraki same-origin navigasyonlarda
  kaybolması.** Yaygın olarak bilinir ama doğrulanmadı. Header'a güveniyorsanız
  test edin; **cookie daha güvenli bir taşıyıcıdır.**
- **Bridge round-trip gecikmesi.** `WKScriptMessageHandler` / `addJavascriptInterface`
  çağrılarının kritik yolda ölçülebilir bir katkı olup olmadığı bilinmiyor.
  Faz 1 enstrümantasyonunda **bridge çağrılarını ayrı bir faz olarak işaretleyin.**

---

## 4.8 Kabul kriterleri

- [ ] Redirect sayısı **native delegate'ten** ölçülüyor ve production'a yazılıyor
- [ ] Token uygulama açılışında, arka planda alınıyor/yenileniyor
- [ ] Cookie `setCookie` callback'i beklenerek yazılıyor
- [ ] Cookie yazımı **ısınma yüklemesinden önce** tamamlanıyor
- [ ] Keşifte MFE'nin isteklerinde `Cookie` header'ı görüldüğü **doğrulandı**
      (`credentials: 'omit'` kullanan MFE'de bu desen çalışmaz)
- [ ] Ekran açılışındaki redirect sayısı **0**
- [ ] İlk API çağrısı 401 alıp retry **etmiyor**
- [ ] Refresh token WebView'e **hiç** verilmiyor
- [ ] OAuth akışı hâlâ harici user-agent'ta (varsa)
- [ ] Cold senaryoda (cookie/cache temizlenmiş) preauth'un farkı ayrıca ölçüldü
- [ ] Android'de preload-intercept kullanıldıysa: TTL, tek-kullanımlık ve
      kullanıcı eşleşmesi test edildi (§4.4)


---

# Faz 5 — Reveal: "hazır olmadan gösterme" (native-only)

**Bu bir performans optimizasyonu DEĞİL, bir ürün kararıdır.**
Gerçek süreyi düşürmez — hatta biraz artırır. Değiştirdiği şey **ne gösterildiğidir.**

**Süre:** 2-3 hafta · **Risk:** düşük (teknik), yüksek (ürün) · **Geri alınabilir:** evet

> **Ön koşul:** Faz 1 §1.6'daki **sezgi kalitesi ölçümü yapıldı**. Yapılmadıysa
> buraya geçmeyin — bu fazın tamamı o sezginin doğruluğuna bağlıdır.

---

## 5.1 Karar

| | Yarım ekran göster | Veri hazır olunca aç |
|---|---|---|
| Kullanıcı ilk ne görür | MFE'nin kendi iskeleti / boş ekran | Native spinner |
| İçerik atlaması (CLS) | Var | Yok |
| Algılanan ilk tepki | Hızlı | Yavaş |
| Ekranın "tamam" olma anı | Belirsiz, kademeli | Net |
| Bankacılıkta yaygın | — | ✅ |
| **Native-only'de risk** | yok | **sezgi yanılabilir** (§5.3) |

**Bu kararı ürün ekibiyle alın** (keşif §0.5-1). Teknik olarak ikisi de uygulanabilir.

> ⚠️ **Skeleton'ın daha iyi olduğu varsayımı ampirik olarak garanti değildir.**
> 136 kişilik, üç gruplu, rastgele atamalı bir deneyde skeleton **tüm metriklerde
> en kötü** koşul çıktı: algılanan bekleme skeleton 2.82 sn / spinner 2.41 sn /
> boş ekran 2.29 sn. *"The meals loaded quickly for me"* ifadesine katılım:
> spinner %74, boş %66, skeleton %59.
> ([Viget, 2017](https://www.viget.com/articles/a-bone-to-pick-with-skeleton-screens/) —
> anlamlılık testi içermiyor, 2017 tarihli)
>
> Bu, "skeleton kullanmayın" demek değil — **"kesin doğru" saymayın** demek.

---

## 5.2 Akış

```
kullanıcı dokunur
   │
   ├─ native ekran ANINDA açılır → nav bar + spinner         ← kullanıcı bunu görür
   ├─ sıcak WebView container'a konur, opacity 0             ← GÖRÜNMEZ
   ├─ native route swap (Faz 3.4) → MFE kendi verisini çeker
   ├─ prob: net-quiet + first-content + 2×rAF                ← HAZIR SEZGİSİ
   └─ native: opacity 1, spinner kaybolur
```

**Bedeli net:** ekran, **en yavaş API çağrısı kadar** gecikir.
Ekran 3 servise bağlıysa üçünün **maksimumunu** bekler, toplamını değil (paralel).

> **MFE işbirliği yapsaydı** burada kesin bir `screen-ready` sinyali olurdu.
> Yok. Native, prob'un sezgisini kullanır — ve o sezginin **yanılabileceğini
> varsayarak** tasarlanmak zorundadır.

---

## 5.3 Hazır-olma sezgisi — native tarafın kararı

Prob üç sinyal üretiyor (Faz 1.4). Native bunları birleştirir:

```swift
/// MFE "hazırım" demiyor. Bu, onun yerine geçen KURALDIR — ve bir vekildir.
struct ReadinessRule {
    /// Route değişimi görüldü mü (swap tuttu mu)
    var sawRouteChange = false
    /// Uçuştaki istek 0'a düştü ve QUIET_MS boyunca öyle kaldı
    var sawNetQuiet = false
    /// DOM'da anlamlı içerik belirdi ve iki kare boyandı
    var sawPainted = false

    /// Ekranın veri çekmesi BEKLENİYOR mu? Keşif §0.3-F'den doldurulur.
    let expectsData: Bool

    var isReady: Bool {
        guard sawRouteChange, sawPainted else { return false }
        return expectsData ? sawNetQuiet : true
    }
}
```

### 🚨 `expectsData` neden route bazında tutulmalı

Veri çekmeyen bir ekranda `net-quiet` beklerseniz, prob hiçbir istek görmediği
için sayaç zaten 0'dır ve `net-quiet` **QUIET_MS sonra** gelir — gereksiz 150 ms.
Veri çeken bir ekranda `net-quiet` beklemezseniz **boş ekran gösterirsiniz.**

Keşif §0.3-F'deki ekran-başına-istek tablosundan bir harita kurun:

```swift
enum RouteExpectation {
    static let expectsData: [String: Bool] = [
        "/accounts": true, "/cards": true, "/transfer": true,
        "/transfer/confirm": false,     // onay ekranı — veri çekmez
        "/legal": false,
    ]
    // Bilinmeyen route: veri çeker varsay (güvenli taraf — zaman aşımı yakalar).
    static func expects(_ route: String) -> Bool { expectsData[route] ?? true }
}
```

### Sezginin bozulduğu üç durum ve ne yapılacağı

| Durum | Belirti | Çözüm |
|---|---|---|
| **Polling / websocket** | `net-quiet` hiç gelmez | Prob'un `IGNORE` listesine ekleyin; ekleyemiyorsanız o route'ta `expectsData = false` yapıp yalnızca `painted`'a güvenin |
| **Zincirleme istek** (A bitince B başlar) | Erken `net-quiet` → yarım ekran | `QUIET_MS`'i artırın (150 → 300). Bedeli: her ekran 150 ms daha geç açılır |
| **Boş liste ekranı** | `first-content` hiç gelmez (yeterli metin yok) | `CONTENT_CHARS` eşiğini düşürün veya o route için `sawPainted` şartını kaldırın |

---

## 5.4 iOS — reveal

WebView **her zaman mount'ta** olmalı (render edebilmesi için); sadece `opacity`
ile gizlenir.

```swift
struct ScreenHost: View {
    @ObservedObject var vm: ScreenViewModel

    var body: some View {
        VStack(spacing: 0) {
            NativeHeader(title: vm.title, loading: !vm.revealed)   // ANINDA çizilir
            ZStack {
                Color(.systemBackground)
                if let wv = vm.webView {
                    WebViewContainer(webView: wv)
                        .opacity(vm.revealed ? 1 : 0)
                        .animation(.easeOut(duration: 0.18), value: vm.revealed)
                }
                if !vm.revealed { NativeLoader(title: vm.title) }
            }
        }
    }
}
```

```swift
// Prob mesajlarını kurala besleyin
func received(tag: String, phase: String, payload: [String: Any]) {
    switch phase {
    case "route-change": rule.sawRouteChange = true
    case "net-quiet":    rule.sawNetQuiet = true
    case "painted":      rule.sawPainted = true
    default: break
    }
    if rule.isReady { vm.revealed = true }
}
```

> ⚠️ `opacity(0)` kullanın, `if vm.revealed { ... }` **kullanmayın.** İkincisi
> WebView'i hierarchy'den çıkarır, render edemez ve `painted` **hiç gelmez** —
> ekran sonsuza kadar spinner'da kalır.

### Android

```kotlin
webView.alpha = if (revealed) 1f else 0f
// ⚠️ View.GONE KULLANMAYIN — Android'de de render'ı durdurur, aynı tuzak.
```

---

## 5.5 Uygulama içi gezinme — native overlay ile

Kullanıcı WebView'in **içinde** bir bağlantıya dokunduğunda native araya girmez.
Ama prob `route-change` gönderir — native bunu duyar ve **üstüne spinner koyar.**

```swift
func received(tag: String, phase: String, payload: [String: Any]) {
    guard phase == "route-change" else { return /* ... */ }
    let newRoute = payload["path"] as? String ?? ""
    guard newRoute != vm.currentRoute else { return }

    vm.currentRoute = newRoute
    rule = ReadinessRule(expectsData: RouteExpectation.expects(newRoute))

    // 🚨 HEMEN spinner göstermeyin. Veri gerektirmeyen geçişler anında biter;
    //    80 ms'lik gecikme, hızlı geçişlerde spinner'ın hiç görünmemesini sağlar.
    //    Referans ölçümde veri gerektirmeyen geçiş 8 ms sürdü.
    scheduleOverlay(after: .milliseconds(80))
}
```

**Önceki ekran görünür kalır, üzerine yarı saydam overlay + spinner gelir.**
WebView'i gizlemeyin — kullanıcı bir an için boşluk görür ve bu, hiçbir şey
yapmamaktan kötüdür.

> ⚠️ **Bu, MFE'nin kendi geçiş animasyonuyla çakışabilir.** MFE zaten kendi
> spinner'ını gösteriyorsa iki spinner üst üste gelir. Keşifte bunu gözleyin;
> çakışıyorsa uygulama içi gezinmede overlay'i **kapatın** ve yalnızca native
> ekran açılışlarında kullanın.

---

## 5.6 Zaman aşımı — zorunlu

Sezgi yanılırsa ekran sonsuza kadar spinner'da kalır. **Her zaman bir kaçış yolu:**

```swift
let revealed = await awaitReadiness(timeout: 8)     // native-only'de daha kısa tutun
if !revealed {
    // Seçenek A: yine de göster (yarım ekranla da olsa) — ÖNERİLEN
    vm.revealed = true
    analytics.log("webview_reveal_timeout", ["route": route, "rule": rule.debugState])
    // Seçenek B: native hata ekranı + tekrar dene
}
```

> **Native-only'de zaman aşımı kesin bir sinyal değil, bir sezgi hatasıdır.**
> Bu yüzden **Seçenek A tercih edilmelidir**: kesin bilgiye dayanmayan bir
> kuralın kullanıcıya hata ekranı göstermesi yanlıştır.
>
> `rule.debugState`'i mutlaka loglayın — hangi sinyalin gelmediğini bilmeden
> sezgiyi düzeltemezsiniz.

**Zaman aşımı oranı sizin en önemli sağlık metriğinizdir.** %1'in üstündeyse
sezgi yanlış ayarlanmış demektir; §5.3'teki tabloya dönün.

---

## 5.7 Ölçülmüş gerçek: bu desen maliyeti backend'e kaydırır

Referans ölçümde (bankacılık benzeri gecikmeler, ekran başına 2-3 paralel servis):

| Faz | Cold | Sıcak + route swap |
|---|---|---|
| JS zinciri | 397 ms | **22 ms** |
| **Veri bekleme** | **435 ms** | **497 ms** |
| Çizim + reveal | 71 ms | 46 ms |
| **Toplam** | 903 ms | 565 ms |

**Veri bekleme kalemi hiçbir WebView stratejisiyle küçülmedi.** Reveal desenini
uyguladığınızda ekran açılış süreniz büyük ölçüde **backend'inizin p95'i olur.**

Uygulama içi gezinmede bu daha da net görüldü:
```
/transfer → /transfer/confirm     8 ms   ← veri gerektirmeyen TEK ekran
diğer tüm geçişler          198–578 ms   ← tamamı API beklemesi
```

> **Sonuç:** Reveal'e geçerseniz, ekran açılış süresini iyileştirmenin yolu
> **API'lerinizi hızlandırmaktan** geçer. Ekran başına servis sayısını azaltmak
> (BFF/aggregation) muhtemelen en yüksek getirili iştir — ve o da bu rehberin
> kapsamı dışındadır. Keşif §0.3-F'deki tabloyu backend ekibiyle paylaşın.

---

## 5.8 Kabul kriterleri

- [ ] Ürün kararı alındı ve yazıldı (yarım ekran mı, bekleme mi)
- [ ] §1.6 sezgi kalitesi ölçümü yapıldı; erken/geç sapma kayıt altında
- [ ] `expectsData` haritası keşif §0.3-F'den kuruldu; bilinmeyen route'lar `true`
- [ ] Prob `IGNORE` listesi polling/analitik isteklerini kapsıyor
- [ ] Native spinner **anında** görünüyor (nav bar dahil)
- [ ] WebView `opacity`/`alpha` ile gizleniyor; `if`/`GONE` **kullanılmıyor**
- [ ] Uygulama içi gezinmede overlay **gecikmeli** açılıyor (hızlı geçişte görünmüyor)
- [ ] MFE'nin kendi spinner'ıyla çakışma kontrol edildi
- [ ] **Zaman aşımı yolu var**, varsayılan davranış "yine de göster"
- [ ] `rule.debugState` zaman aşımında loglanıyor
- [ ] Zaman aşımı oranı production'da izleniyor (hedef < %1)


---

# Faz 6 — Kalıcı paylaşılan WebView (native-only)

**En yüksek tavan, en yüksek maliyet.** İki bağımsız üretim sistemi bu mimariye
ulaştı — bu rehberdeki en güçlü mimari sinyal.

**Süre:** 1-2 çeyrek · **Risk:** yüksek (mimari) · **Geri alınabilir:** zor

---

## 6.1 Yakınsayan kanıt

| Desen | Hotwire Native (Basecamp/HEY) | Shopify Mobile Bridge (~600 ekran) |
|---|---|---|
| WebView yaşam döngüsü | Navigation stack başına **tek** paylaşılan `WKWebView` | Havuzlanır, kullanıldıktan sonra **atılmaz** |
| Ekranlar arası geçiş | `VisitableView`'lar arasında **re-parent** | `TransportableView` — *"without losing state or data"* |
| Beyaz ekran önleme | Ayrılan ekranda render edilmiş **screenshot** bırakılır | Geçişten önce WebView'in **anlık görüntüsü** alınır |
| Yayımlanmış rakam | yok | P75 6 sn → 1.4 sn (paket sonucu) |

Kaynaklar: [Hotwire Native iOS](https://native.hotwired.dev/ios/reference) ·
[Shopify Engineering](https://shopify.engineering/mobilebridge-native-webviews)

> ⚠️ Hotwire kanıtı **server-rendered Turbo/HTML** bağlamındandır, React SPA değil.
> Mimari transfer edilebilir; performans rakamı yoktur.

---

## 6.2 Faz 3'ten farkı

| | Faz 3 (sıcak havuz) | Faz 6 (kalıcı paylaşılan) |
|---|---|---|
| Ekran kapandığında | WebView atılır, yenisi ısıtılır | WebView **kalır**, route ısınma hedefine döner |
| Isınma maliyeti | Her ekran açılışından sonra tekrar ödenir | **Bir kez** ödenir |
| Ekranlar arası state | Kaybolur | **Korunur** (HTTP cache, auth context, React state) |
| Geri navigasyonu | Yeniden yükleme | Screenshot → anında |
| Bellek | Kullanım anında 1 instance | Sürekli 1 instance |
| Bağımsız deployability | Korunur | **Zayıflar** (tek shell'e giderseniz) |

> **Referans ölçümde Faz 6, Faz 3'ten anlamlı biçimde iyi çıkmadı (565 vs 565 ms).**
> Sebep: o düzenekte Faz 3 de her koşudan önce yeniden ısıtılıyordu ve **ısınma
> süresi ölçüme girmiyordu.** Kalıcı modelin asıl avantajı ısınmayı hiç
> tekrarlamamaktır — bunu görmek için ısınma maliyetini de sayan bir senaryo gerekir.
>
> **Kendi ölçümünüzde bunu ayırın:** kullanıcı ard arda 5 ekran açtığında toplam
> süre nedir?

---

## 6.3 Üç uygulama modeli — ikisi native, biri kapsam dışı

### Model A — Stack başına paylaşılan WebView (Hotwire'ın birebir karşılığı) ✅ native
Her navigation stack bir WebView tutar, ekranlar arasında re-parent edilir.
Microfrontend'ler hâlâ ayrı SPA'lar olabilir ve **kodlarına dokunulmaz.**

- ✅ Tamamen native tarafta uygulanır
- ✅ Bağımsız deployability korunur
- ✅ Mimari risk düşük
- ⚠️ Farklı microfrontend'ler arası geçişte JS boot hâlâ ödenir (ayrı origin/bundle)

### Model B — Tek shell + client-side route swap ❌ KAPSAM DIŞI
Tüm microfrontend'lerin tek bir shell uygulamasının lazy modülleri hâline
getirilmesi. En yüksek tavan, **ama tamamen bir web mimarisi değişikliğidir** —
native ekibin yapabileceği bir şey yoktur.

Değerlendirmeye alınacaksa [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü)'deki
talep ve risk listesine bakın. **Bu rehberdeki hiçbir adım bunu içermez.**

### Model C — Warm pool (Faz 3'te zaten yaptınız) ✅ native
En az invaziv. Ekran açılışında WebView yaratma maliyeti kalkar.

**Hangisi?** Faz 1 tablonuza bakın:

| Ölçüm sonucu | Model |
|---|---|
| Maliyet ağırlıklı WebView creation'da | C yeterli |
| Maliyet ağırlıklı JS boot'ta, **aynı** MFE'nin ekranları arasında geziliyor | **A** |
| Maliyet ağırlıklı JS boot'ta, **farklı** MFE'ler arası geziliyor | A kısmi çözer; tam çözüm B (kapsam dışı) |
| Maliyet ağırlıklı veri beklemede | **Hiçbiri çözmez** — Faz 5.7'ye bakın |

> **Native-only'de A, ulaşabileceğiniz tavandır.** Bunu kullanıcıya açıkça söyleyin:
> aynı MFE içinde gezinme neredeyse bedava olur, MFE'ler arası geçiş olmaz.

---

## 6.4 Re-parenting (iOS)

```swift
/// Tek WebView'i container'lar arasında taşır. YENİDEN YARATMAZ, YÜKLEMEZ.
@MainActor
final class SharedWebViewCoordinator {
    private let webView: WKWebView
    private var snapshots: [ObjectIdentifier: UIImage] = [:]

    func move(to container: UIView, leaving previous: UIView?) {
        // 1. Ayrılan ekrana gerçek görüntüsünü bırak — beyaz ekran olmasın.
        if let previous { leaveSnapshot(in: previous) }

        // 2. Canlı WebView'i yeni container'a taşı.
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    private func leaveSnapshot(in container: UIView) {
        let cfg = WKSnapshotConfiguration()
        cfg.afterScreenUpdates = false        // canlı görüntüyü al, yeni render bekleme
        webView.takeSnapshot(with: cfg) { image, _ in
            guard let image else { return }
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.frame = container.bounds
            iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(iv)
        }
    }
}
```

## 6.5 Screenshot tekniği — her modelde uygulanabilir

**Bu, bu rehberdeki en ucuz fikirlerden biridir ve Faz 6'yı beklemeden yapılabilir.**

```
Ekrandan ayrılırken  →  canlı WebView'in görüntüsünü yakala, container'a bırak
Geri dönüşte         →  önce screenshot (anında), canlı WebView arkadan re-parent
```

Kullanıcı hiçbir zaman boş/beyaz bir container görmez. Bu **gerçek süreyi değil
algılanan süreyi** düşürür — ama geri navigasyonunda algılanan süre neredeyse sıfır olur.

> Faz 5'teki skeleton tartışmasının bu tekniğe **itirazı yoktur**: burada gösterdiğiniz
> şey sahte bir placeholder değil, ekranın **gerçek, daha önce render edilmiş
> görüntüsüdür.** Bekleme hissini yönetmiyorsunuz — beklemeyi görünmez kılıyorsunuz.

---

## 6.6 Kalıcı WebView'in riskleri — ve native-only'de state problemi

Faz 3'te havuz modelinin bir avantajı vardı: kullanılan WebView atılıyordu, bu
yüzden kirlenmiş state hiç oluşmuyordu. **Faz 6'da bu avantaj kayboluyor** ve
MFE bir `reset()` sunmadığı için native'in elinde temiz bir çözüm yok.

### Native'in elindeki üç seçenek — hepsinin bedeli var

| Seçenek | Ne yapar | Bedeli |
|---|---|---|
| **Hafif hedefe geri dön** (`__nativeRoute.go('/legal')`) | Görünen ekranı boşaltır | React ağacı unmount olur ama modül state'i, cache'i, listener'ları **bellekte kalır** |
| **Periyodik hard reload** | `webView.reload()` — her şeyi temizler | Isınmayı **baştan öder**; kullanıcı beklemeyecek bir anda yapın |
| **Hiçbir şey yapma** | — | Uzun oturumlarda bellek ve bayat state birikir |

**Önerilen bileşim:**

```swift
func onWebScreenClosed() {
    // 1. Görüneni boşalt — bir sonraki açılış temiz DOM'a gelsin.
    swapRoute(shared, to: config.warmupTargetRoute)

    // 2. Sınır koy: N ekran veya T dakika sonra tamamen tazele.
    screensSinceReload += 1
    if screensSinceReload >= 20 || Date().timeIntervalSince(lastReload) > 30 * 60 {
        scheduleReloadWhenIdle()     // uygulama arka plana gittiğinde veya
                                     // kullanıcı native ekranlardayken
    }
}
```

> 🚨 **`scheduleReloadWhenIdle` gerçekten idle beklemeli.** Kullanıcı bir web
> ekranı açarken reload tetiklerseniz cold baseline'a düşersiniz ve bunu
> ölçümde **rastgele yavaş açılışlar** olarak görürsünüz — sebebini bulmak çok zordur.

### Hata yakalama — native tarafta

MFE'ye error boundary ekleyemezsiniz. Prob, sayfa genelindeki hataları yakalar:

```js
// webview-probe.js'e eklenir
window.addEventListener('error', function (e) {
  window.__probe.post('js-error', { msg: String(e.message).slice(0, 300) });
});
window.addEventListener('unhandledrejection', function (e) {
  window.__probe.post('js-rejection', { msg: String(e.reason).slice(0, 300) });
});
```

Native bunu duyduğunda: telemetriye yazar, ekran hâlâ açılmadıysa **native hata
ekranı** gösterir ve paylaşılan WebView'i **tazeler**. Kalıcı modelde bir hata
tek ekranı değil **sonraki tüm ekranları** etkileyebilir — bu yüzden hard reload
burada Faz 3'tekinden daha kritiktir.

### Diğer riskler

| Risk | Önlem |
|---|---|
| **Content process termination** (iOS) | `webViewWebContentProcessDidTerminate` → yeniden kur + son route'a dön |
| **Bellek büyümesi** | 30 dakikalık gezinme sonrası artışı ölçün; §6.6'daki sınırı ona göre koyun |
| **Auth izolasyonu** | Farklı güven seviyeli MFE'ler **aynı** WebView'i paylaşmamalı — ayrı instance tutun |
| **Cross-MFE state sızıntısı** | `localStorage`/`sessionStorage` origin başına ayrıdır; aynı origin'deki farklı MFE'ler birbirini görür |

---

## 6.7 Kabul kriterleri

- [ ] Model seçildi (**A veya C**; B kapsam dışı) ve gerekçesi Faz 1 tablosuna dayandırıldı
- [ ] WebView ekranlar arasında re-parent ediliyor, yeniden yaratılmıyor
- [ ] Ayrılan ekranda screenshot bırakılıyor, geri dönüşte anında görünüyor
- [ ] Ekran kapanınca hafif ısınma hedefine dönülüyor
- [ ] **Sınırlı hard reload** kuralı var (N ekran / T dakika) ve yalnızca idle'da çalışıyor
- [ ] Prob `js-error` / `js-rejection` gönderiyor; native bunu telemetriye yazıyor
- [ ] Hata sonrası paylaşılan WebView tazeleniyor
- [ ] Content process termination'da son route'a geri dönülüyor
- [ ] Bellek: 30 dakikalık gezinme sonrası artış ölçüldü ve kabul edilebilir
- [ ] Farklı güven seviyeli MFE'ler aynı WebView'i paylaşmıyor
- [ ] **Ard arda 5 ekran açma** senaryosu ölçüldü (Faz 3 vs Faz 6 farkı burada görünür)


---

# Faz 7 — İleri seviye: yerel asset, speculative loading

**Ölçümünüz ağ fazının veya bundle boyutunun baskın olduğunu gösteriyorsa.**
Bu fazdaki her şey platform asimetrisi taşır — iOS ve Android farklı davranır.

---

## 7.1 ⚠️ Platform asimetrisi tablosu

| Yetenek | Android | iOS |
|---|---|---|
| Resmî pre-warm API | ✅ `WebViewCompat.startUpWebView` (1.16.0 stable) | ❌ yok |
| `https://` isteklerini intercept | ✅ `shouldInterceptRequest` | ❌ **imkânsız** |
| Yerel asset origin'i | ✅ gerçek HTTPS, same-origin | ⚠️ custom scheme, **farklı origin** |
| Prerender | ✅ `prerenderUrlAsync` (WebView 135+) | ❌ yok |
| Prefetch | ⚠️ var, ama interceptor'la çakışır | ❌ yok |
| Script-seviyesi profiling (LoAF) | ✅ provider ≥ 123 | ❌ Chromium-only |

**Okunacak sonuç:** iOS, Android'in resmî hızlandırma araçlarının neredeyse
hiçbirine sahip değil. **iOS'ta kazanç mimariden (Faz 3/6) gelmek zorunda.**

---

## 7.2 Yerel asset servisi

> **Kapsam notu:** Bu, MFE'nin **kaynak koduna** değil, **derlenmiş çıktısına**
> dokunur — native uygulama bundle'ı kendi içinde taşır veya OTA ile indirir.
> MFE ekibinden istenen tek şey **build artifact'ına erişimdir**, kod değişikliği değil.
>
> ⚠️ Ama bir ön koşulu var: MFE'nin asset'leri **göreli yollarla** referans
> vermesi gerekir. Mutlak CDN URL'leri gömülüyse yerel servis çalışmaz ve bu
> bir **web talebi** olur.



### Android — `WebViewAssetLoader` (resmî yol)

```kotlin
val assetLoader = WebViewAssetLoader.Builder()
    .setDomain("appassets.example.com")            // kendi domaininiz olabilir
    .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
    .addPathHandler("/ota/", WebViewAssetLoader.InternalStoragePathHandler(context, otaDir))
    .build()

webView.webViewClient = object : WebViewClientCompat() {
    override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest) =
        assetLoader.shouldInterceptRequest(req.url)
}
webView.loadUrl("https://appassets.example.com/assets/index.html")
```

İçerik **normal, opaque olmayan, same-origin HTTPS dokümanı** gibi davranır —
`fetch`, cookie, storage hepsi çalışır.

> `InternalStoragePathHandler` OTA ile indirilen bundle'ı aynı origin altında
> servis etmek için vardır.

### iOS — custom scheme ZORUNLU

Apple'ın dokümanı: *"It is a programmer error to register a handler for a scheme
WebKit already handles, such as `https`, and this method raises an
`invalidArgumentException` if you try to do so."*

`NSURLProtocol` da işe yaramaz: alt sınıf `+canInitWithRequest:` alır ama
**hiç instantiate edilmez** ([WebKit Bug 138169](https://bugs.webkit.org/show_bug.cgi?id=138169), ~12 yıldır açık).

```swift
let config = WKWebViewConfiguration()
config.setURLSchemeHandler(AppAssetSchemeHandler(), forURLScheme: "bankapp-assets")
webView.load(URLRequest(url: URL(string: "bankapp-assets://app/index.html")!))
```

Apple'ın scheme adı kuralları: *"must start with an ASCII letter, and may contain
only ASCII letters, numbers, the `+`, `-`, and `.` characters."* Ve tavsiyesi:
*"include the name of your app or company in any custom scheme names."*

### 🚨 iOS'ta custom scheme'in bedeli: origin değişir

| Etkilenen | Ne olur |
|---|---|
| **CORS** | API'niz `bankapp-assets://` origin'ini tanımalı, yoksa preflight patlar |
| **Cookie** | Custom scheme origin'i `https://api.banka.com` cookie'lerini otomatik göndermez |
| **Storage** | localStorage/IndexedDB farklı partition'a yazar |
| **Service Worker** | Custom scheme altında kullanılabilirliği **doğrulanamadı** |

**Bu, iOS ve Android'i mimari olarak ayrıştıran en büyük tek farktır.** Backend
CORS politikanızı baştan iki origin'i kapsayacak şekilde tasarlayın.

### ⚠️ Naif scheme handler HTTP'den yavaş olabilir

Referans ölçümde senkron `Data(contentsOf:)` kullanan bir handler, loopback HTTP'den
**daha yavaş** çıktı. Streaming ve cache olmadan yazmayın:

```swift
func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    // ⚠️ Bunu main thread'de senkron yapmayın; büyük dosyalar için streaming kullanın.
    queue.async {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            return task.didFailWithError(Err.notFound)
        }
        DispatchQueue.main.async {
            task.didReceive(URLResponse(url: url, mimeType: mime,
                                        expectedContentLength: data.count,
                                        textEncodingName: "utf-8"))
            task.didReceive(data)
            task.didFinish()
        }
    }
}
```

---

## 7.3 Code splitting — ⚠️ kapsam dışı, ama kararı ölçümünüz verir

Bundle'ı bölmek bir **web build konfigürasyonu değişikliğidir**; native tarafta
yapılamaz. Buraya konmasının tek sebebi: **talep etmeye değer olup olmadığını
sizin ölçümünüz söyler** ve cevap çoğu zaman "hayır"dır.

Referans ölçüm: 1954 KB tek bundle vs 870 KB entry + 8 × ~134 KB chunk.

| Strateji | Tek bundle | Split | Fark |
|---|---|---|---|
| Cold baseline | 903 | 907 | ≈ 0 |
| **Warm blank** (`about:blank`) | 790 | **646** | **−18%** |
| Sıcak + route swap | 565 | 559 | ≈ 0 |
| Kalıcı paylaşılan | 565 | 587 | ≈ 0 |

**Tek net kazanan: dokunma anında tam JS boot ödeyen strateji.**

> 🚨 **Okunacak sonuç:** Faz 3'ü **A seçeneğiyle** (`about:blank`) uyguladıysanız
> split talep etmek anlamlı olabilir. **B veya C ile** uyguladıysanız JS boot'u
> zaten dokunmadan önce ödüyorsunuz ve split'in size verecek bir şeyi yok —
> **talep etmeyin.**

### ⚠️ Split'in bedeli localhost'ta görünmez
Referans ölçümde route mount 22 ms → 76 ms'ye çıktı: chunk indirme. Loopback'te
bu neredeyse bedava, **gerçek mobil şebekede fazladan bir round-trip** ve bilançoyu
tersine çevirebilir. **Split talebini gerçek şebekede ölçmeden yapmayın.**

Talep metni: [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü).

---

## 7.4 Android speculative loading — üç API, birbirinin yerine geçmez

| API | Ne indirir | React SPA'da değeri |
|---|---|---|
| `Profile.preconnect()` | DNS + TCP + TLS (URL bilmeden çağrılabilir) | Orta — **en ucuz kazanç** |
| `Profile.prefetchUrlAsync()` | **Yalnızca HTML** | **Düşük** — JS/CSS indirmez |
| `WebViewCompat.prerenderUrlAsync()` | Sayfayı gizli renderer'da **çalıştırır** | Yüksek |

### 🚨 Prefetch, interceptor mimarisiyle ÇAKIŞIR

Doküman net:
1. **Prefetch edilen HTML için `shouldInterceptRequest()` tamamen atlanır** — auth
   header injection'ınız ve yerel asset mantığınız uygulanmaz.
2. **Navigasyon anında interceptor `null` dönmezse WebView prefetch cache'ini
   tamamen bypass eder.**

Yani `WebViewAssetLoader` kullanıyorsanız **prefetch fiilen hiçbir işe yaramaz.**
İkisi aynı anda kullanılamaz.

> **Prerender'ın aynı çakışmayı yaşayıp yaşamadığı dokümante edilmemiştir.**
> Kendi deneyinizle test edin.

### Prerender
Chrome'un tanımıyla CWV etkisi: *"near zero LCP, reduced CLS, improved INP."*

```kotlin
// Kullanıcı listede bir karta dokunmadan önce (ör. scroll durduğunda)
WebViewCompat.prerenderUrlAsync(
    webView, targetUrl, cancellationSignal, executor,
    object : PrerenderOperationCallback { /* ... */ }
)
```

> Android'de prerender **Java'dan sürülür**, sayfaya `<script type="speculationrules">`
> enjekte ederek değil. Web'de öğrendiğiniz pattern burada geçerli değil.
>
> **iOS'ta prerender yoktur.** Aynı etkiyi elde etmenin tek yolu Faz 3/6'teki
> elle sıcak tutulan WebView'dir.

### Prerender'ın gizli bedeli: tahmin
Kullanıcının hangi ekrana gideceğini bilmiyorsanız boşa pil ve veri harcarsınız.
Tahmin isabet oranınız hakkında yayımlanmış veri yok. **Kalıcı WebView'de bu
sorun yoktur** — React zaten ayakta, hangi ekrana giderse gitsin.

### ⚠️ API yüzeyi hızlı değişiyor
`androidx.webkit` son 12 ayda değişti (`setSpeculativeLoadingConfig` →
`setMaxPrerenders`/`PrefetchCache`; `SpeculativeLoadingParameters` →
`PrefetchParameters`/`PrerenderParameters`). Blog yazılarındaki imzalara güvenmeyin;
release notes'u kaynak alın.

---

## 7.5 Paylaşılan bağımlılık tekilliği — ⚠️ kapsam dışı

Farklı microfrontend'lerin React'i ayrı ayrı indirmesi gerçek bir maliyettir ama
çözümü web tarafındadır (ortak, sürümlü, immutable bir URL'den servis etmek).
Native tarafta yapılabilecek tek şey **ölçüp göstermektir**:

```swift
// Faz 2.1'deki asset denetimini MFE'ler arasında karşılaştırın.
// Aynı kütüphane iki farklı URL'den iniyorsa duplikasyon vardır.
```

single-spa, büyük kütüphanelerin sayfada **yalnızca bir kez** yüklenmesini
*"crucial"* sayar; framework'ün (React/Vue/Angular) **tek kez** yüklenmesi
gerektiğini söyler. react-router gibi küçük kütüphanelerin duplike olması kabul
edilebilir görülür.

> ⚠️ **"Büyük" ve "küçük" için hiçbir sayısal KB sınırı verilmez.** Sektörde dolaşan
> "V8 50–100 KB bundle bütçesi önerir" iddiası adversarial doğrulamayı **geçemedi**
> (0-3) ve V8'in yayınına atfedilemez. Kendi bütçenizi cihaz çarpanıyla (§7.6)
> kendi ölçümünüzden türetin.

Ayrıca import maps ile Module Federation **birbirinin alternatifidir** — ikisinden
biri seçilmeli, karıştırılmamalıdır. Bu da bir web kararıdır.

Talep metni: [`09-web-sozlesmesi.md`] (bu dosyada: Ek — Web sözleşmesi bölümü).

---

## 7.6 Cihaz sınıfı çarpanı — her bundle kararında hatırlayın

| Cihaz | Üst segmente göre JS execution |
|---|---|
| Pixel 3 (üst segment) | 1× |
| Moto G4 (orta segment) | **3–4×** |
| Alcatel 1X (<$100) | **6×+** |

([V8, 2019](https://v8.dev/blog/cost-of-javascript-2019) — ölçüm 2019, cihazlar 2016–2018)

Geliştirici telefonunda 300 ms olan boot, kullanıcı tabanınızın orta segmentinde
~1 saniyedir. **"Sadece 200 KB daha" üst segmentte fark etmez, orta segmentte
3-4 kat ağırlıkla geri döner.**

---

## 7.7 Kabul kriterleri

- [ ] Yerel asset kararı verildi; MFE'nin göreli yol kullandığı **doğrulandı**
- [ ] iOS'ta custom scheme seçildiyse origin değişikliğinin CORS/cookie etkisi çözüldü
- [ ] iOS scheme handler senkron/bloklayıcı değil
- [ ] Prefetch, `shouldInterceptRequest` mimarisiyle birlikte **kullanılmıyor**
- [ ] Prerender kullanılıyorsa interceptor çakışması test edildi
- [ ] Prerender tahmin isabet oranı ölçülüyor (isabetsiz prerender pil ve veri harcar)
- [ ] Bundle/duplikasyon bulguları **ölçülüp** web ekibine rapor edildi (talep §09'da)
- [ ] Hiçbir web build kararı native taraftan **varsayılarak** uygulanmadı


---

# Faz 8 — Doğrulama, anti-pattern'ler, çürütülen iddialar

---

## 8.1 Anti-pattern kontrol listesi

Her biri gerçek bir hatadır; çoğu **sessizce** kazancı sıfırlar.

### Kapsam ve süreç

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 1 | **Keşif raporu onaylanmadan kod yazmak** | Yanlış varsayımla uygulanan faz sessizce sıfır kazanç üretir | 0 |
| 2 | **MFE kaynak koduna dokunmak** | Kapsam ihlali; başka ekiplerin deployment'ını kırarsınız | Kapsam |
| 3 | Web tarafında yapılması gereken bir işi native'de taklit etmek | Teşhisi çok zor davranış farkları | 4.3 |
| 4 | Bir fazı "kesin işe yarar" diye sunmak | Ölçüm olmadan hiçbir iddia geçerli değil | 1 |

### Ölçüm

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 5 | Native mesaj handler'ında bilinmeyen tipleri yutmak | Ölçüm mesajları sessizce kaybolur | 1.5 |
| 6 | Prob'un `IGNORE` listesini doldurmamak | `net-quiet` **hiç gelmez**, Faz 5 sonsuza kadar spinner gösterir | 1.4 |
| 7 | Sezgi kalitesini videoyla doğrulamadan Faz 5'e geçmek | Yarım ekran veya gereksiz bekleme, sebebi bilinmez | 1.6 |
| 8 | `Date()` / duvar saati kullanmak | Sistem saati değişince ölçüm kayar | 1.3 |
| 9 | Geliştirici telefonunda test etmek | Orta segmentte JS **3–4×**, ucuzda **6×+** yavaş | 7.6 |
| 10 | Hedefi 2.5 sn LCP olarak koymak | Bu bir algı limiti değil, 2020 web dağılımı uzlaşması | 8.3 |

### Hızlı kazanımlar

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 11 | `startUpWebView` çağırıp aynı frame'de WebView yaratmak | Kazanç **tam sıfır** | 2.6 |
| 12 | `setCookie` çağırıp hemen `load`/`loadUrl` | İlk istek cookie'siz → 401 → redirect zinciri | 2.2 |
| 13 | Eski `setCookie(url, value)` overload'ı | Tamamlanma sinyali yok | 2.2 |
| 14 | `CookieManager.flush()` kritik yolda | **Bloklar ve I/O yapar** | 2.2 |
| 15 | `WKUserScript`'i WebView'den sonra eklemek | O navigasyon için geç kalır — **prob hiç çalışmaz** | 2.3 |
| 16 | `no-cache` yerine `no-store` (sunucuda) | Tüm bundle her açılışta yeniden iner | 2.1 |
| 17 | `file://` veya `loadData()` ile bundle yüklemek | Opaque origin → `fetch()` **çalışmaz** | 2.7 |
| 18 | Sıcak WebView tutup process termination'ı ele almamak | Kullanıcı **beyaz dikdörtgen** görür | 2.5 |

### Sıcak WebView ve route swap

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 19 | **Route swap'ın çalıştığını doğrulamamak** | Kullanıcı **yanlış ekranı** görür — bu listedeki en kötü hata | 3.4 |
| 20 | Swap için tam-yükleme fallback'i yazmamak | Router uyumsuzluğunda ekran hiç değişmez | 3.4 |
| 21 | `pushState` çağırıp `popstate` dispatch etmemek | Hiçbir olay üretilmez, router haberdar olmaz | 3.4 |
| 22 | Isınma susturmasını göstermeden önce kaldırmamak | Gerçek ekran veri çekemez, boş kalır | 3.3 |
| 23 | C seçeneğinde susturmayı hiç kurmamak | Görüntülenmemiş ekranlar analitiğinizi bozar | 3.3 |
| 24 | `about:blank` ile ısıtıp route-swap kazancı beklemek | JS hiç çalışmadı; tavan **−13%** | 3.2 |
| 25 | Sıcak WebView'i hierarchy dışında tutmak | Render etmeyebilir; "ısıttım ama fark yok" | 3.5 |
| 26 | `evaluateJavaScript`'in async overload'ı (Swift) | Çağrı bloklar, ölçümü bozar | 3.4 |
| 27 | Ekran kapandıktan sonra yeniden ısıtmamak | İkinci açılış cold baseline'a döner | 3.7 |
| 28 | Isınma bitmeden ölçüm başlatmak | Kazanç ısınma süresiyle maskelenir | 3.9 |

### Reveal ve kalıcı WebView

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 29 | Reveal'i `if revealed { WebView }` / `View.GONE` ile yapmak | WebView hierarchy'den çıkar, hiç render etmez | 5.4 |
| 30 | `expectsData` haritası olmadan reveal | Veri çekmeyen ekranda 150 ms boşa bekleme veya boş ekran | 5.3 |
| 31 | Reveal'de zaman aşımı yolu koymamak | Ekran sonsuza kadar spinner'da kalır | 5.6 |
| 32 | Zaman aşımında hata ekranı göstermek | Sezgi hatası kullanıcıya sistem hatası gibi görünür | 5.6 |
| 33 | Uygulama içi gezinmede spinner'ı **gecikmesiz** açmak | 8 ms'lik geçişte bile spinner çakar | 5.5 |
| 34 | Kalıcı modelde hard reload sınırı koymamak | Bellek ve bayat state birikir | 6.6 |
| 35 | Hard reload'u idle beklemeden tetiklemek | Rastgele yavaş açılışlar; sebebi bulunamaz | 6.6 |

### İleri seviye

| # | Anti-pattern | Sonuç | Faz |
|---|---|---|---|
| 36 | Prefetch'i `shouldInterceptRequest` ile birlikte kullanmak | Prefetch **tamamen bypass edilir** | 7.4 |
| 37 | iOS'ta `https` için `setURLSchemeHandler` denemek | `invalidArgumentException` fırlatır | 7.2 |
| 38 | Android preload-intercept'te TTL/tek-kullanım koymamak | Kullanıcı bayat veri görür | 4.4 |
| 39 | Preload-intercept'te kullanıcı eşleşmesini doğrulamamak | **Veri sızıntısı** | 4.4 |

---

## 8.2 ❌ Çürütülen iddialar — hiçbir yerde kullanmayın

Bunlar sektörde yaygın olarak alıntılanır ama üç bağımsız doğrulayıcıyla yapılan
adversarial kontrolü **geçemedi**:

| İddia | Oy |
|---|---|
| "V8, bundle başına **50–100 kB** bütçe önerir" | 0-3 |
| "Module Federation duplikasyonu bant genişliğinde maliyet yaratmaz" | 0-3 |
| "Parse/compile artık baskın maliyet değil" | 1-2 |
| App Store Guideline **2.5.2 / 4.7 / 4.7.2** yorumlarının OTA web-asset güncellemesine uygulanması | 0-3 |

> Politika soruları için blog yazılarına değil, kendi compliance ekibinize danışın.

---

## 8.3 Hedef belirleme — 2.5 sn LCP'yi hedef almayın

Google'ın kendi dokümanı, 2.5 sn LCP eşiğinin bir **insan algısı limiti olmadığını**
açıkça söylüyor: Nisan 2020 CrUX verisinde mobil origin'lerin yalnızca **%42'si**
bunu karşılıyordu (1.5 s %13, 2 s %27 — bu ikisi "tutarlı biçimde ulaşılabilir değil"
diye elendi). Altındaki HCI araştırması da tek bir sayı vermiyor; kabaca **0.3–3 saniye**
aralığı. ([web.dev](https://web.dev/articles/defining-core-web-vitals-thresholds))

**Doğru hedef belirleme:**
1. **Native ekranlarınızın açılış süresini ölçün** — kullanıcının referansı odur.
2. WebView hedefini **o sayıya göre** koyun.
3. Kendi metriğinizi tanımlayın: **"dokunma → ilk anlamlı içerik"**. Gömülü,
   referrer'sız, tarayıcı chrome'suz bir WebView ekranı için LCP'nin anlamlılığı
   doğrulanmamıştır.

---

## 8.4 Faz bazında kabul testi

Her fazdan sonra bu ölçümü koşun ve faz tablosunu kaydedin.

### Test matrisi
```
strateji  × ekran × cihaz sınıfı × ağ koşulu × cold/warm
```

**Minimum:** her hücrede **n ≥ 30**. Referans ölçümde n=3 olan hücreler
yorumlanamayacak kadar gürültülüydü.

### Sağlık metrikleri (production'da izleyin)
| Metrik | Neden |
|---|---|
| `screen-ready` p50 / p95, cihaz sınıfı kırılımlı | Ana metrik |
| **`webview_route_swap.ok` oranı** | %99'un altındaysa Faz 3'ün kazancı yok — **native-only'nin en kritik metriği** |
| Sıcak instance **hazır olma oranı** | Düşükse Faz 3 kazancı yok |
| **Reveal zaman aşımı oranı** | Sezginin doğruluğu + backend sağlığı (hedef < %1) |
| `webContentProcessDidTerminate` **sıklığı** | Sıcak WebView'in gerçek güvenilirliği |
| Ekran açılışındaki **redirect sayısı** | Faz 4 regresyonlarını yakalar |
| Isınma sonrası **analitik sayacı = 0** | Faz 3 regresyonunu yakalar |
| **`js-error` / `js-rejection` sıklığı** | Kalıcı modelde bir hata sonraki tüm ekranları etkiler |
| **Prob enjeksiyon başarı oranı** | `doc-start` hiç gelmiyorsa ölçümün tamamı kördür |

---

## 8.5 Regresyon testleri

Bu fazlar **sessizce bozulur.** CI'a koyun:

```
□ Isınma hedefi yüklendikten sonra hiçbir analitik event gönderilmedi
□ Isınma hedefi yüklendikten sonra hiçbir /api/* çağrısı yapılmadı (B seçeneğinde)
□ Route swap her hedef route için başarılı (webview_route_swap.ok = 1)
□ Router sürümü yükseltildikten SONRA route swap hâlâ çalışıyor    ← en kırılgan nokta
□ Faz tablosunda doc-start sütunu sıcak stratejide BOŞ
□ Prob documentStart'ta enjekte ediliyor (doc-start geliyor)
□ Hash'li asset'ler immutable, index.html no-cache + ETag
□ Ekran açılışında redirect sayısı = 0
□ Sıcak WebView hierarchy içinde
□ Aynı route arka arkaya iki kez açılabiliyor
```

> 🚨 **Bu listedeki en kritik satır dördüncüsü.** Route swap, MFE ekibinin
> **habersizce** yaptığı bir router yükseltmesiyle bozulabilir. Native ekip bunu
> ancak CI'daki bu testle yakalar. MFE'lerin sürüm yükseltmelerini tetikleyen bir
> smoke test kurun — kapsam dışı olsa bile **haberdar olmak** kapsam içidir.

---

## 8.6 Bu rehberin bilinçli boşlukları

Aşağıdakiler için **doğrulanmış kaynak bulunamadı.** Tahminle doldurulmadı;
kendi ölçümünüzü gerektirirler:

| Soru | Neden önemli |
|---|---|
| İlk `WKWebView` instantiation maliyeti vs. havuzdan alınan | iOS'ta warm pool'un gerçek değeri |
| `WKProcessPool` paylaşımı modern iOS'ta anlamlı mı | Apple "limit sonrası paylaşır" diyor, limiti söylemiyor |
| Warm WebView havuzunun bellek/jetsam maliyeti | Kaç instance tutabileceğiniz |
| `webContentProcessDidTerminate` pratikte ne sıklıkta | Warm pool'un gerçek güvenilirliği |
| Hierarchy dışı `WKWebView` render ediyor mu | Faz 2'nin temel varsayımı |
| Service Worker, WKWebView'de custom scheme altında çalışıyor mu | Offline stratejisinin temeli |
| WebView HTTP cache'i app update'ten sağ çıkıyor mu | Cache header'larınız doğru olsa bile |
| Prerender'ın interceptor'la çakışması | Faz 7.4 |
| Module Federation / import maps'in **ölçülmüş** runtime maliyeti | Framework seçimi |
| React duplikasyonunun KB ve parse/compile ms karşılığı | Faz 7.5'in önceliği |
| Bridge round-trip gecikmesi | Kritik yolda mı |
| Sentetik `popstate`'in router sürümleri arası uyumluluğu | Faz 3'ün tamamı buna bağlı — **her sürümde yeniden test edin** |
| `net-quiet` sezgisinin gerçek "hazır"a sapması | Faz 5'in doğruluğu (§1.6 ile kendiniz ölçün) |
| Isınma susturmasının kuyruklu analitiği engelleyip engellemediği | Faz 3.3'ün doğruluğu |
| Prob'un `fetch` yamasının MFE davranışına etkisi | Enjeksiyonun yan etkisi — regresyon testi gerekir |
| Native skeleton + anında nav bar deseninin algısal etkisi | Elimizde destekleyici değil, hafif **zayıflatıcı** dolaylı kanıt var |

> **Process prewarm (yarat-at) için bir cevap var:** referans uygulamada üç ayrı
> koşuda da baseline'ın **gerisinde** kaldı. Ölçülebilir faydası görülmedi.

---

## 8.7 Son söz

Bu rehberdeki hiçbir teknik için **"şu kadar ms kazandırır"** garantisi yoktur.
Sektörde bu konuda yayımlanmış, doğrulanabilir tek vaka çalışması Shopify'ınkidir
(P75 6 sn → 1.4 sn) ve o da bir **paket sonucudur**.

Bu rehberin verdiği şey **doğrulanmış mekanizmalar, API semantiği ve mimari
desenlerdir.** Sayılar sizin ölçümünüzden gelecek.

Native-only kapsamda iki ek gerçeği kabul edin:

1. **Tavan daha düşüktür.** MFE işbirliğiyle ulaşılan −37%'yi native-only'de ancak
   ısınma hedefiniz gerçekten sessizse veya Faz 6'ya geçerseniz yakalarsınız.
2. **Daha kırılgandır.** Route swap ve hazır-olma sezgisi, MFE'nin haber vermeden
   değişebilecek davranışına dayanır. Bu yüzden §8.5'teki regresyon testleri
   isteğe bağlı değildir.

**Faz 0'ı (keşif) ve Faz 1'i (ölçüm) atlamayın.**


---

# Ek — Web sözleşmesi (⛔ BU REHBERİN KAPSAMI DIŞINDA)

> **Bu dosya bir uygulama talimatı değildir.** Buradaki hiçbir madde native ekip
> tarafından yapılmaz ve bu rehberi izleyen AI ajanı **bu dosyadaki hiçbir şeyi
> kendisi uygulamaz.**
>
> Amacı tek: native-only tavanın nerede bittiğini göstermek ve web ekipleriyle
> konuşulacaksa **neyin ne kazandıracağını ölçülmüş sayılarla** masaya koymak.

---

## A.1 Ne zaman bu dosyayı açarsınız

Faz 1'den Faz 7'ye kadar her şeyi uyguladınız ve hâlâ hedefinizin altındasınız.
Önce şu üç soruyu cevaplayın:

1. **Faz 1 tablonuzda hangi kalem baskın?**
   - JS zinciri baskınsa → A.2 ve A.4 anlamlı
   - Veri bekleme baskınsa → **hiçbiri anlamlı değil**, A.6'ya (backend) gidin
   - Redirect baskınsa → Faz 4'ü tam uyguladığınızdan emin olun, sonra A.3
2. **Faz 3'te hangi ısınma hedefini kullandınız?** A veya C ise A.2 en yüksek getiri.
3. **Route swap başarı oranınız kaç?** %99'un altındaysa A.2 bunu da çözer.

---

## A.2 `/warmup` route'u — en yüksek getirili tek talep

**Talep:** Her microfrontend'e, yan etkisi olmayan bir `/warmup` route'u ve
küçük bir native köprüsü eklenmesi.

**Ölçülmüş karşılığı:** JS zinciri **397 ms → 22 ms** (18×), toplam ekran
açılışında **−37%** (referans uygulama).

### Web ekibinden istenen — tam metin

> `/warmup` route'u şunları **yapmayacak**: veri çekmeyecek, analitik
> göndermeyecek, görünür içerik çizmeyecek, auth kontrolü tetiklemeyecek.
> Tek işi JS motorunu ve framework'ü ayağa kaldırmaktır.
>
> Router'ın **varsayılan** route'u bu olacak — native bir route vermediğinde
> uygulama buraya düşecek.
>
> Ayrıca `window.__mfe = { navigate(route), reset(), currentRoute() }` köprüsü
> mount'tan sonra tanımlanacak ve `reset()` **görünen ekranı da sıfırlayacak**.

```jsx
export default function Warmup() {
  useEffect(() => { window.__mfe?.ready?.() }, [])
  return <div data-route="warmup" aria-hidden="true" style={{ height: '100%' }} />
}
```

### Native'e kazandırdığı dört şey

| Kazanç | Native-only'deki karşılığı |
|---|---|
| Yan etkisiz ısınma | §3.3'teki susturma — **kırılgan**, kuyruklu analitiği kesemez |
| Kesin route swap | §3.4'teki sentetik `popstate` — **router sürümüne bağlı** |
| Kesin `reset()` | §6.6'daki hard reload — **ısınmayı baştan ödetir** |
| Temiz varsayılan durum | yok |

> 🚨 **`reset()` gerçekten boşaltmalı.** Sadece hash'i değiştirip görünen ekranı
> aynı bırakırsanız, aynı route ikinci kez açıldığında bileşen remount olmaz,
> veri yeniden çekilmez ve hazır sinyali hiç gelmez. Referans uygulamada tam
> olarak bu hata yaşandı ve koşuların %64'ü zaman aşımına uğradı.

---

## A.3 Kesin `screen-ready` sinyali

**Talep:** Ekranın tüm verisi geldiğinde ve ilk boyama yapıldığında native'e
tek bir sinyal gönderilmesi.

```js
requestAnimationFrame(() => requestAnimationFrame(() => {
  window.webkit?.messageHandlers?.probe?.postMessage({ type: 'screen-ready', route })
  window.__ProbeBridge?.post?.(JSON.stringify({ type: 'screen-ready', route }))
}))
```

**Native'e kazandırdığı:** Faz 5'teki **sezgi tamamen ortadan kalkar.**
`net-quiet` + `first-content` + `expectsData` haritasının tamamı silinir;
erken/geç reveal hatası sıfırlanır; zaman aşımı oranı düşer.

> Bu talep **A.2'den daha ucuzdur** (birkaç satır) ve Faz 5'in en kırılgan
> parçasını ortadan kaldırır. Web ekibi tek bir şey yapacaksa **bu olmalı** —
> en düşük maliyet, en yüksek kırılganlık azaltımı.

---

## A.4 Oturum ve önyüklenmiş veriyi okuma

**Talep:** MFE'nin `window.__SESSION__` ve `window.__PRELOADED__` global'lerini
varsa kullanması.

```js
const s = window.__SESSION__ ?? null
fetch(url, { headers: s ? { authorization: `Bearer ${s.token}` } : {} })

function usePreloaded(route) {
  const p = window.__PRELOADED__?.[route]
  if (p) delete window.__PRELOADED__[route]   // tek kullanımlık — bayat veri gösterme
  return p ?? null
}
```

**Native'e kazandırdığı:** Token round-trip'i kalkar; **iOS'ta da** veri önyükleme
mümkün olur (native-only'de bu yalnızca Android'de yapılabiliyordu — §4.4).

**Güvenlik ödünü:** Faz 4.5'teki tablo aynen geçerlidir. Kısa ömürlü ve dar
kapsamlı token; refresh token **asla**; WebView'de CSP; `forMainFrameOnly: true`.

> ⚠️ Referans ölçümde preauth varyantı sade sıcak varyanttan **anlamlı biçimde
> iyi çıkmadı** (522 vs 565 ms). Bu talebi "hız" gerekçesiyle değil, **iOS'taki
> veri önyükleme boşluğunu kapatmak** gerekçesiyle yapın.

---

## A.5 Asset ve build talepleri

| Talep | Ne zaman | Ölçülmüş etkisi |
|---|---|---|
| Hash'li asset `immutable`, `index.html` `no-cache`+`ETag` | Faz 2.1 denetiminde `cached:false` görülüyorsa | Tekrar açılışlarda ağ fazı ciddi düşer |
| Asset'lere **göreli yol** ile referans | Faz 7.2 (yerel servis) isteniyorsa | Ön koşul — olmadan yerel asset çalışmaz |
| Paylaşılan React'in tek, sürümlü, immutable URL'den servisi | Aynı kütüphane iki URL'den iniyorsa | Ölçülmedi; ikinci MFE React'i hiç indirmez |
| Code splitting | **Yalnızca** Faz 3'ü A seçeneğiyle (`about:blank`) uyguladıysanız | Warm blank'te **−18%**; diğer stratejilerde **≈ 0** |

> 🚨 **Code splitting'i körlemesine istemeyin.** Referans ölçümde route swap'lı
> stratejide farkı sıfırdı ve kalıcı WebView'de **kötüleştirdi** (565 → 587 ms).

---

## A.6 Backend / BFF — asıl tavan burada

Faz 5.7'deki ölçüm net: reveal desenini uyguladığınızda ekran açılış süreniz
büyük ölçüde **backend p95'iniz** olur.

```
/transfer → /transfer/confirm     8 ms   ← veri gerektirmeyen TEK ekran
diğer tüm geçişler          198–578 ms   ← tamamı API beklemesi
```

**Getirisi en yüksek iş muhtemelen budur ve bu rehberdeki hiçbir teknik onu
yerine koyamaz:**

- Ekran başına servis sayısını azaltmak (BFF / aggregation endpoint)
- En yavaş servisin p95'ini düşürmek — ekran onun kadar bekler, toplamın değil
- Keşif §0.3-F'deki ekran-başına-istek tablosunu backend ekibiyle paylaşın

---

## A.7 Model B — tek shell mimarisi

Tüm microfrontend'lerin tek bir shell'in lazy modülleri hâline getirilmesi
(Faz 6.3, Model B). **En yüksek tavan, en yüksek risk, tamamen web tarafı.**

| | |
|---|---|
| ✅ | React tek kez parse/compile edilir; ekran açılışı = tek dynamic import |
| ⚠️ | Bağımsız deployability **zayıflar** — sürüm skew kontratı gerekir |
| ⚠️ | Blast radius büyür — shell'deki bir hata **tüm** web ekranlarını etkiler |
| ⚠️ | Auth/session izolasyonu kaybolur |
| ❌ | Ölçülmüş bir performans rakamı **yok** |

Bunu bir performans işi olarak değil, bir **mimari kararı** olarak ele alın.
Karar verilirse route bazında error boundary ve sürüm uyumluluk kontratı zorunludur.

---

## A.8 Talep önceliklendirme — tek tabloda

Web ekibinin sınırlı kapasitesi varsa sıra budur:

| Sıra | Talep | Maliyet | Native'de neyi kurtarır |
|---|---|---|---|
| 1 | **`screen-ready` sinyali** (A.3) | birkaç satır | Faz 5'in tamamının kırılganlığı |
| 2 | **`/warmup` + `__mfe` köprüsü** (A.2) | 1-2 gün / MFE | Faz 3'ün tavanı (−13% → −37%) |
| 3 | **Cache header'ları** (A.5) | konfigürasyon | Tekrar açılışlardaki ağ fazı |
| 4 | **BFF / servis azaltma** (A.6) | çeyrek | Kalan sürenin çoğu |
| 5 | Oturum okuma (A.4) | 1 gün | iOS'taki veri önyükleme boşluğu |
| 6 | Paylaşılan bağımlılık (A.5) | orta | MFE'ler arası duplikasyon |
| 7 | Code splitting (A.5) | orta | **Çoğu durumda hiçbir şey** |
| 8 | Model B (A.7) | 1-2 çeyrek | Ölçülmemiş |
