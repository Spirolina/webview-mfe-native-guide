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
| ⚠️ Ayrı tutulan | Web ekiplerinden **istenebilecek** şeyler → [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md) — bunlar bu işin kapsamı değil, yalnızca tavanın nerede olduğunu gösterir |

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

**AI ajanı için kural:** [`00-kesif.md`](00-kesif.md)'deki envanter raporunu
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
| [`00-kesif.md`](00-kesif.md) | **Envanter, karar matrisi, onay kapısı** | ✅ |
| [`01-olcum.md`](01-olcum.md) | Enjekte edilen ölçüm probu — MFE'ye dokunmadan faz tablosu | ✅ |
| [`02-hizli-kazanimlar.md`](02-hizli-kazanimlar.md) | Cookie sırası, beyaz flash, process termination, Android pre-warm | ✅ (cache header'ları hariç) |
| [`03-sicak-webview.md`](03-sicak-webview.md) | Sıcak havuz + native route swap + ısınmayı susturma — **çekirdek** | ✅ |
| [`04-auth-ve-veri.md`](04-auth-ve-veri.md) | Redirect zincirini kritik yoldan çıkarma, oturum aktarımı | ✅ |
| [`05-reveal.md`](05-reveal.md) | "Hazır olmadan gösterme" + native hazır-olma sezgisi | ✅ |
| [`06-kalici-webview.md`](06-kalici-webview.md) | Tek paylaşılan WebView, re-parenting, screenshot | ✅ |
| [`07-ileri-seviye.md`](07-ileri-seviye.md) | Yerel asset servisi, prerender/prefetch | ✅ |
| [`08-dogrulama.md`](08-dogrulama.md) | Kabul kriterleri, anti-pattern listesi, çürütülen iddialar | ✅ |
| [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md) | **Kapsam dışı.** Web ekiplerinden istenecekler ve karşılığında ne kazanılır | ❌ |

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
