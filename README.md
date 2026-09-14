# WebView Microfrontend Hızlandırma — Native Uygulama Rehberi

Gömülü WebView'lerde React microfrontend çalıştıran büyük bir native mobil
uygulamada (iOS + Android), ekran açılış süresini düşürmek için **yalnızca native
tarafta** uygulanacak adım adım rehber.

**Kapsam:** Microfrontend'lerin React kaynak koduna dokunulmaz, yeni bir MFE
yazılmaz. Web ekiplerinden istenebilecekler ayrı bir ek olarak, kapsam dışı
işaretiyle tutulur.

---

## Başka bir ortamda nasıl kullanılır

```bash
git clone https://github.com/Spirolina/webview-mfe-native-guide.git
```

Hedef mobil uygulamanın kod tabanında çalışan AI ajanına **tek bir dosya** verin:

```
IMPLEMENTATION-GUIDE.md      ← 3126 satır, 124 KB, kendi kendine yeter
```

Bu dosya bütün fazları, kodları ve karar tablolarını içerir; başka hiçbir dosyaya
veya bu repoya erişim gerektirmez. Bölüm bölüm okumak isterseniz `guide/` altındaki
dosyalar aynı içeriği taşır.

### Ajana verilecek istem (önerilen)

> Ekte bir uygulama rehberi var. Bu kod tabanında **yalnızca native tarafı**
> değiştireceksin; microfrontend'lerin React kaynak koduna dokunmayacaksın.
>
> Rehberdeki **Faz 0 bir kapıdır**: envanter raporunu doldurup bana sunmadan ve
> onayımı almadan hiçbir dosyayı değiştirme. Raporda "bulunamadı" kalan her alanı
> bana sor, varsayımla ilerleme.

---

## İçerik

| Dosya | İçerik |
|---|---|
| [`IMPLEMENTATION-GUIDE.md`](IMPLEMENTATION-GUIDE.md) | **Tek dosya hâli** — ajana verilecek olan budur |
| [`guide/README.md`](guide/README.md) | Kapsam, faz haritası, ölçülmüş referans sonuçlar |
| [`guide/00-kesif.md`](guide/00-kesif.md) | **Envanter, karar matrisi, onay kapısı** — atlanamaz |
| [`guide/01-olcum.md`](guide/01-olcum.md) | Enjekte edilen ölçüm probu — MFE'ye dokunmadan faz tablosu |
| [`guide/02-hizli-kazanimlar.md`](guide/02-hizli-kazanimlar.md) | Cookie sırası, beyaz flash, process termination, Android pre-warm |
| [`guide/03-sicak-webview.md`](guide/03-sicak-webview.md) | Sıcak havuz + native route swap + ısınmayı susturma — **çekirdek** |
| [`guide/04-auth-ve-veri.md`](guide/04-auth-ve-veri.md) | Redirect zincirini kritik yoldan çıkarma, oturum aktarımı |
| [`guide/05-reveal.md`](guide/05-reveal.md) | "Hazır olmadan gösterme" + native hazır-olma sezgisi |
| [`guide/06-kalici-webview.md`](guide/06-kalici-webview.md) | Tek paylaşılan WebView, re-parenting, screenshot |
| [`guide/07-ileri-seviye.md`](guide/07-ileri-seviye.md) | Yerel asset servisi, prerender/prefetch |
| [`guide/08-dogrulama.md`](guide/08-dogrulama.md) | Kabul kriterleri, 39 anti-pattern, çürütülen iddialar |
| [`guide/09-web-sozlesmesi.md`](guide/09-web-sozlesmesi.md) | **Kapsam dışı.** Web ekiplerinden istenecekler ve karşılığı |

Bölümleri düzenlerseniz tek dosyayı yeniden üretmek için:

```bash
./guide/build-single-file.sh     # → IMPLEMENTATION-GUIDE.md
```

---

## Native-only nasıl mümkün oluyor

Tek mekanizma: **native, sayfaya kendi JavaScript'ini enjekte edebilir**
(iOS `WKUserScript` / Android `addDocumentStartJavaScript`). Bu script MFE'nin
kodundan önce çalışır; ölçüm probu, route sürücüsü ve hazır-olma sezgisi buradan
kurulur.

| MFE'den istenseydi | Native tarafta karşılığı |
|---|---|
| Faz `mark()`'ları | `fetch`/XHR yamalı ölçüm probu |
| `/warmup` route'u | Isınma hedefi seçimi + içerik kuralıyla susturma |
| `window.__mfe.navigate()` | `pushState` + sentetik `popstate` ya da `location.hash` |
| `screen-ready` sinyali | `net-quiet` + `first-content` + 2×rAF sezgisi |

---

## Ölçülmüş referans sonuçlar

iOS 26.3 Simulator, 1954 KB React bundle, 7 ekran, ekran başına 2-3 paralel API
çağrısı, bankacılık benzeri gecikme profili, n=22.

| Strateji | Native-only? | Ekran açıldı p50 | Baseline'a göre |
|---|---|---|---|
| Cold baseline | — | 903 ms | — |
| Process prewarm (yarat-at) | ✅ | 953 ms | **daha kötü** |
| Sıcak WebView (`about:blank`) | ✅ | 790 ms | −13% |
| Sıcak + `/warmup` + route swap | ❌ web gerekli | 565 ms | −37% |
| Kalıcı paylaşılan WebView | ✅ | 565 ms | −37% |

**Asıl bulgu:** sıcak strateji JS zincirini 397 ms → 22 ms düşürüyor (18×), ama
toplam yalnızca %37 iniyor — çünkü veri beklemesine (≈435–497 ms) hiçbir WebView
stratejisi dokunamıyor.

> ⚠️ Bu sayılar simulator ve localhost ölçümüdür. Kendi uygulamanız için geçerli
> değildir; oranlar fikir verir, sayılar vermez. Rehberin Faz 1'i kendi
> tablonuzu üretmek içindir.
