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
   [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md) gündeme girer; hayırsa native-only
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
