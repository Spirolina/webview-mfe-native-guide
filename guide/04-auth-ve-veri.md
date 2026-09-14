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
[`09-web-sozlesmesi.md`](09-web-sozlesmesi.md).

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
