# App calcio Reggio — idea e requisiti di prodotto

Documento di lavoro per definire l'app prima di iniziare a scrivere codice. Le decisioni confermate sono distinte dalle domande ancora aperte.

## Visione

Un'app mobile semplice e utile per i tifosi della Reggina 1914, con notizie, informazioni sportive e uno spazio di conversazione tra tifosi. Il prodotto è un ibrido tra aggregatore informativo e community, non un social network basato sui contenuti pubblicati dagli utenti.

## Nome e identità dell'app — da scegliere

- Il nome della squadra nel documento è scritto correttamente “Reggina”, con due g.
- Il nome dell'app dovrebbe distinguersi dal nome e dai segni ufficiali della società, così da non suggerire un'app ufficiale.
- Si cerca un nome breve che richiami chiaramente Reggio, la squadra o i tifosi, senza presentarsi come app ufficiale.
- Nome scelto: “Amaranto Feed”. Sottotitolo: “Le news del calcio reggino”.
- Il nome è una scelta di prodotto; la disponibilità di marchi simili e di nome su store e domini resta da controllare prima del lancio.
- Colore principale dell'interfaccia: `#841230`.

## Piattaforme

- Obiettivo iniziale: pubblicazione su Google Play.
- Compatibilità tecnica desiderata: iOS grazie a Flutter.
- Pubblicazione sull'App Store al momento non prevista per la quota annuale; si potrà rivalutare in futuro.
- UI Android desiderata: aspetto nativo e aggiornato secondo le linee grafiche Android correnti (da identificare nella fase di architettura/design).

## Regole dell'interfaccia

- Nessuna top bar fissa nelle schede principali: il Feed mostra “Notizie” come intestazione scorrevole insieme al contenuto; classifica, calendario, chat e profilo usano swipe e barra inferiore per navigare. Le pagine di dettaglio di una notizia e della prossima partita mostrano una barra superiore con il pulsante Indietro. Gli aggiornamenti avvengono tramite gesto.

## Pubblico e uso

- Pubblico: tifosi della Reggina.
- Progetto personale e ricreativo: deve restare utile ma semplice da gestire.

## Funzionalità previste

### Notizie — priorità principale

- Aggregatore di notizie sulla Reggina, inizialmente tramite feed RSS.
- Cercare e selezionare feed RSS di fonti ritenute attendibili.
- Fonti individuate e feed verificati il 15 ottobre 2026:
  - TuttoReggina, sezione “REGGINA”: <https://www.tuttoreggina.com/rss/?section=44>. L'endpoint risponde come RSS 2.0; gli elementi includono titolo, data, descrizione, link e immagine `enclosure`.
  - Il Tifoso Reggino, categoria Reggina: <https://iltifosoreggino.it/category/calcio/reggina/feed/>. L'endpoint risponde come RSS 2.0 e include titolo, data, link e metadati immagine (`media:content`/`enclosure`).
  - Feed generale Il Tifoso Reggino: <https://iltifosoreggino.it/feed/> (alternativa più ampia, include sport locali oltre alla Reggina).
- TuttoReggina dichiara il servizio RSS gratuito per uso personale e invita a contattare la redazione per usi commerciali; l'impiego in un'app pubblica va chiarito con la redazione prima del lancio.
- Il feed dell'app mostra notizie provenienti da fonti esterne.
- Non sono previsti, almeno all'inizio, post o commenti degli utenti nel feed.
- Ogni notizia è presentata in modo essenziale con immagine di copertina/anteprima e titolo.
- Toccando una notizia, l'utente legge la pagina originale della fonte dentro l'app tramite browser integrato.
- L'app resta un aggregatore: non deve ripubblicare il testo completo degli articoli; il traffico deve indirizzarsi al sito della fonte.

### Informazioni sportive

- Prossima partita.
- Nel Feed, la prossima partita appare in una card compatta con data, orario e stemmi delle due squadre.
- Toccando la card si apre una pagina di dettaglio con competizione, data, orario, stadio e luogo; la pagina offre un tasto Indietro.
- Calendario delle partite.
- Classifica e statistiche della Reggina (per esempio marcatori) sono possibili funzioni successive, non priorità dell'alfa.

### Versione alfa stabile

- L'app Flutter è multipiattaforma; la verifica corrente è centrata su Android.
- Le schede inferiori sono Classifica, Calendario, Feed, Chat e Profilo. Il Feed è la scheda iniziale e occupa il centro della barra; si può cambiare scheda con swipe orizzontale o toccando la barra. Toccando Feed mentre è già selezionato, la lista torna in cima e aggiorna le notizie.
- Il Feed aggrega gli RSS di TuttoReggina e Il Tifoso Reggino, ordinando gli articoli per data e mostrando anteprima, titolo e fonte. Il testo completo resta sul sito originale, aperto nella WebView con barra e tasto Indietro.
- La card della prossima partita usa dati LND e apre una pagina di dettaglio con barra e tasto Indietro.
- Classifica e calendario sono recuperati direttamente da LND nel client Flutter, con cache locale sul dispositivo. Il calendario consente di cambiare giornata e mostra i punteggi degli incontri conclusi.
- Il tema segue le impostazioni del dispositivo per impostazione predefinita; dal Profilo si può forzare il tema chiaro o scuro.
- Le notifiche RSS usano un controllo in background ogni 30 minuti circa, gestito dal sistema operativo e subordinato alla connessione e al permesso notifiche. Il Profilo permette di disattivarle. Gli articoli già notificati sono ricordati sul dispositivo; più novità nello stesso controllo producono un riepilogo. Toccando la notifica si apre la notizia più recente. L’attivazione non invia gli articoli precedenti e vengono escluse le notizie senza data o più vecchie di 24 ore.
- Chat e accesso sono segnaposto e non sono implementati nell'alfa. Statistiche avanzate e marcatori sono rimandati.

### Community

- Chat globale in cui gli utenti possono scambiarsi informazioni.
- La chat viene dopo notizie e informazioni sportive come priorità.
- Dimensione iniziale della community attesa contenuta; non si vuole dipendere da un feed di post degli utenti che rischierebbe di restare vuoto.
- Per leggere e inviare messaggi in chat è richiesto il login.
- La prima versione prevede una sola stanza pubblica per tutti i tifosi.
- Gli utenti possono segnalare un messaggio; il blocco di altri utenti non è previsto inizialmente.
- Stanze aggiuntive sono una possibile evoluzione futura se la community cresce.

## Account e dati — da definire

- Notizie e informazioni sportive sono consultabili senza registrazione.
- Per la chat si desidera una registrazione semplice, con due alternative: accesso con Google oppure account locale con username e password, senza collegare Google.
- L'autore vorrebbe evitare, se possibile, di detenere dati personali e mantenere bassa la complessità operativa.
- I metodi previsti sono stati scelti; provider tecnico, dati strettamente necessari, conservazione e aspetti GDPR sono ancora da valutare.

Nota terminologica: Google Authenticator è comunemente usato per la verifica in due passaggi; “Accedi con Google” è un metodo distinto di autenticazione tramite account Google.

## Domande aperte

- Quali fonti di notizie sono ammesse e come si attribuiscono i contenuti?
- Quali dati sportivi servono e da quali fonti si possono ottenere?
- Quali controlli minimi servono per gestire spam, abusi e segnalazioni?
- Quali schede avrà la barra inferiore e quali saranno già funzionanti nell'alfa?
- Serve aggiungere una cache locale per le notizie o basta il recupero all'apertura e su richiesta?

## Decisioni

| Tema | Decisione attuale | Stato |
|---|---|---|
| Nome app | Amaranto Feed | Scelto, verifica disponibilità da fare |
| Sottotitolo | Le news del calcio reggino | Confermato |
| Pubblico | Tifosi della Reggina | Confermato |
| Feed | Aggregatore di notizie, inizialmente via RSS | Confermato |
| Fonti notizie | Cercare feed RSS di fonti attendibili | Da ricercare |
| Scheda notizia nel feed | Immagine di copertina/anteprima e titolo | Confermato |
| Apertura notizia | Pagina originale della fonte in browser integrato | Confermato |
| Attribuzione e diritti | Usare i dati del feed per l'anteprima e indirizzare alla fonte; verificare condizioni delle fonti selezionate | Da verificare per ogni fonte |
| Parte superiore del Feed | Riquadro prossima partita con data, orario, luogo, competizione e stemmi delle squadre | Confermato |
| Tocco sul riquadro partita | Apre il calendario completo | Confermato |
| Alfa | Feed, banner prossima partita e barra inferiore; alcune pagine possono essere vuote | Confermato |
| Classifica e statistiche dettagliate | Valutare in seguito | Fuori priorità alfa |
| Post e commenti nel feed | Non previsti nella fase iniziale | Confermato |
| Contenuti principali | Notizie, partita e dati sportivi | Confermato |
| Community | Chat globale, priorità successiva | Confermato |
| Accesso a notizie e dati sportivi | Libero, senza registrazione | Confermato |
| Accesso alla chat | Login richiesto | Confermato |
| Metodi di login per la chat | Google oppure account locale con username e password | Confermato |
| Struttura iniziale della chat | Una stanza pubblica | Confermato |
| Segnalazione messaggi | Disponibile | Confermato |
| Blocco utenti | Non previsto inizialmente | Confermato |
| Stanze aggiuntive | Possibile evoluzione futura | Fuori dalla prima versione |
| Dati e gestione account | Minimizzare dati e lavoro operativo; dettagli da valutare | Da definire |

## Architettura — discussione iniziale

Decisione iniziale confermata:

- App multipiattaforma in Flutter: un progetto per Android e iOS, con interfaccia Material 3 per l'aspetto Android.
- Fase attuale: definire prima l'interfaccia e lo stack di base. Login e chat sono rimandati; le schermate pubbliche non richiedono account.

Indicazioni ancora da valutare:

- Backend gestito solo quando serviranno le funzioni che ne hanno bisogno, soprattutto account, chat in tempo reale e segnalazioni.
- Feed RSS e dati della prossima partita sono dati pubblici; nella prima implementazione il client legge direttamente le fonti.
- Implementazione iniziale del feed: lettura diretta dei due endpoint RSS dal client, senza backend; recupero all'apertura del Feed e aggiornamento manuale. Una cache locale si potrà aggiungere se serve.
- Evitare nella prima versione un server proprietario sempre acceso; valutare servizi gestiti e funzioni serverless.

Scelte architetturali ancora aperte:

- Backend gestito e relativo fornitore, da valutare quando si pianificheranno account e chat.
- Account locale basato solo su username/password oppure username pubblico associato a una credenziale privata (per esempio email) utile per recuperare l'account.
- Modalità e fonte dei dati per calendario e prossima partita.

### Dati Serie D, Girone I — ricognizione iniziale

- Non è stata individuata un'API pubblica documentata della LND; la LND pubblica però un archivio ufficiale consultabile di calendario e classifica per stagione e girone: <https://gare.lnd.it/competizione/dipartimento-interregionale/?campionato=ID&girone=I&stagione=2026>. L'archivio è a scopo informativo e specifica che, in caso di contrasto, prevalgono i Comunicati Ufficiali.
- API-Football/API-Sports elenca esplicitamente “Serie D - Girone I” e pubblicizza un piano gratuito da 100 richieste al giorno, ma l'autore non è riuscito a completare la registrazione; per questo progetto il servizio è escluso.
- Alternative verificate: AnySport dichiara copertura Serie D e offre una prova gratuita di 7 giorni, poi il piano mostrato parte da 99 USD/mese; iSports API elenca “Italy Serie D” e offre una prova di 15 giorni (200 richieste al giorno, poi la chiave viene disattivata). Nessuna delle due è al momento una fonte gratuita permanente verificata per il Girone I.
- L'accesso gratuito all'API non concede automaticamente i diritti di pubblicazione dei dati in un'app: i termini API-Sports demandano all'utente la verifica e l'ottenimento delle autorizzazioni eventualmente necessarie.
- Lo scraping dell'archivio LND è possibile ma non è l'unica strada: può rompersi se cambia il sito e i dati vanno confrontati con i Comunicati Ufficiali. In alternativa, per il banner e il calendario iniziali si può valutare l'inserimento manuale con aggiornamento settimanale.
- Per un'alfa senza costi ricorrenti, le opzioni pratiche rimaste sono inserire i dati iniziali manualmente dai Comunicati Ufficiali oppure automatizzare l'acquisizione dal portale LND, verificando i dati con i Comunicati Ufficiali e mantenendo una cache.
- Decisione aggiornata: nessun backend applicativo da ospitare. Flutter legge direttamente la pagina ufficiale LND, estrae il payload Inertia e normalizza classifica, calendario, nomi e loghi.
- La cache locale usa SharedPreferences, separa stagioni e giornate e dura sei ore. Il refresh manuale forza una nuova richiesta; se LND non risponde, vengono mostrati gli ultimi dati validi salvati per quella richiesta e stagione, con il timestamp originale. Le giornate mai caricate richiedono una connessione.
- Il calendario parte dalla giornata corrente LND e consente di navigare andata e ritorno. Le giornate storiche non sostituiscono la selezione della giornata corrente.
- Il parser usa i loghi referenziati dalla risposta LND senza copiarli negli asset. Mantiene gli alias delle società e i loghi alternativi per i segnaposto generici. Classifica: PG, V, N, S, DR e P. Partite: data, orario, campo, squadre e risultato solo per incontri conclusi.
- LND può cambiare payload o parametri: il client mostra un errore con possibilità di riprovare quando non dispone di cache valida. L'archivio rimane informativo e i Comunicati Ufficiali prevalgono.
- News RSS e dati LND richiedono accesso ai rispettivi siti pubblici; non sono necessarie chiavi API né un database condiviso. La destinazione attuale è Android nativo; un'eventuale versione web richiederà una soluzione per le restrizioni CORS delle fonti.
- Chat e accesso rimangono segnaposto. La cache sul dispositivo non sincronizza dati tra utenti; una futura chat richiederà un progetto separato per trasporto e persistenza dei messaggi.
