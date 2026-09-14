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
