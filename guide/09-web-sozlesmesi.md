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
