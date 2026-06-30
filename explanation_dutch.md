# Uitleg bij het ontgrendelen van de rekenmachine

Hoewel het hacken van de rekenmachine niet zo simpel is, is het van belang dat de beveiliging nog wat verder wordt opgeschroefd. In dit document beschrijf ik hoe ik de hack heb kunnen doen, maar eerst even wat voorkennis:

---

## Wat is de NumWorks N0120?

De NumWorks N0120 is een grafische rekenmachine die draait op een [STM32H7](https://nl.wikipedia.org/wiki/STM32) microcontroller. Deze chip is gemaakt door STMicroelectronics en is een krachtige [32-bit ARM Cortex processor](https://nl.wikipedia.org/wiki/ARM-architectuur). De rekenmachine bevat twee geheugens: een intern flash-geheugen in de STM32 chip zelf (waar de bootloader staat) en een extern QSPI-flash geheugen (waar de firmware staat). NumWorks heeft de chip beveiligd om te voorkomen dat gebruikers aangepaste firmware kunnen installeren.

---

## Het opstartproces van de rekenmachine

Het opstarten van de rekenmachine gebeurt in grofweg 2 stappen:

1. De rekenmachine start op, en er wordt een klein programmaatje genaamd de **bootloader** ingeladen en uitgevoerd. Dit programmaatje doet op de NumWorks een aantal dingen:
   - Hardware initialiseren (beeldscherm, flash-geheugen)
   - Checken of de firmware die op de rekenmachine staat valide is
   - De firmware op de rekenmachine starten

### Stap 1: Hardware initialiseren

De eerste stap is het initialiseren van de hardware. De QSPI-flash (het opslaggeheugen) wordt verbonden, en de bootloader kijkt waar hij de firmware in dat geheugen kan vinden. Daarnaast activeert de bootloader **RDP (Readout Protection)**, om te voorkomen dat iemand in het geheugen kan kijken.

### Stap 2: Firmware valideren

Vervolgens kijkt de bootloader in de firmware, om de firmware te valideren. Het valideren van de software gebeurt op basis van een "digitale handtekening". NumWorks gebruikt hier waarschijnlijk een [asymmetrisch cryptografisch algoritme](https://nl.wikipedia.org/wiki/Asymmetrische_cryptografie) zoals **RSA** of **ECDSA**. De bootloader bevat een publieke sleutel die gebruikt wordt om de handtekening van de firmware te verifiëren. Alleen firmware die ondertekend is met de bijbehorende private sleutel (die alleen NumWorks bezit) wordt als geldig beschouwd. Aan de structuur van de software kan de bootloader "zien" of deze officieel is.

### Stap 3: Firmware starten

Daarna start de rekenmachine de firmware uit een van de twee slots, als deze geldig zijn. NumWorks gebruikt een zogeheten **A/B-systeem**: er zijn twee firmware-slots in het geheugen. Dit is een veiligheidsmechanisme dat vaak gebruikt wordt bij updates. Als een update mislukt, kan de rekenmachine terugvallen op de vorige werkende versie uit het andere slot. 

Mocht geen enkele firmware door de validatiecheck komen, dan toont de rekenmachine het **recovery-modus scherm**. In deze modus kan de rekenmachine via USB verbinding maken met een computer om nieuwe firmware te ontvangen.

---

## Het laden van de eigen firmware

Om eigen firmware te kunnen laden, moeten we in het geheugen kunnen kijken. En dat niet alleen, we moeten het ook kunnen overschrijven. Dat is simpeler gezegd dan gedaan, maar het bestaat uit deze stappen:

1. RDP uitzetten
2. Eigen bootloader en firmware programmeren
3. Bootloader en firmware op de rekenmachine zetten

### Waarom wil NumWorks dit voorkomen?

NumWorks heeft de rekenmachine beveiligd om verschillende redenen. Ten eerste willen ze controle houden over welke software op hun hardware draait, onder andere voor kwaliteitsgarantie en om ervoor te zorgen dat de rekenmachine voldoet aan examenreglementen. Daarnaast bevat de officiële firmware mogelijk intellectueel eigendom dat NumWorks wil beschermen. Door de beveiliging te implementeren, proberen ze te voorkomen dat gebruikers aangepaste firmware installeren die mogelijk examenmodes omzeilt of andere functionaliteit toevoegt die niet toegestaan is tijdens examens.

### De RDP-niveaus uitgelegd

RDP bestaat in 3 niveaus:

| Niveau | Beveiliging | Beschrijving |
|--------|------------|--------------|
| **0** | Geen beveiliging | Debug-toegang is volledig open, geheugen kan vrij gelezen en geschreven worden |
| **1** | Gedeeltelijke beveiliging | Het is mogelijk om debug-toegang te krijgen, maar bij het lezen/schrijven naar het geheugen wordt het geheugen compleet gewist |
| **2** | Maximale beveiliging | Debug-toegang is uit, het is niet eens mogelijk om te verbinden met de rekenmachine |

Idealiter hebben we dus RDP 0. We kunnen hier komen vanaf RDP 1 door debug-toegang te krijgen (en de flash te gaan lezen/schrijven) en in de [option bytes](https://www.st.com/resource/en/application_note/an4701-proprietary-code-readout-protection-on-microcontrollers-of-the-stm32f4-series-stmicroelectronics.pdf) van de chip de bytes van RDP 1 te overschrijven met 0.

**Waarom staat STMicroelectronics downgrade toe?**

Hier zit een interessante ontwerpkeuze van STMicroelectronics: waarom staat het downgraden van RDP 1 naar RDP 0 toe? Dit lijkt een beveiligingslek, maar het is eigenlijk een bewuste keuze. STMicroelectronics wil ontwikkelaars de mogelijkheid geven om een beveiligde chip te "resetten" voor hergebruik of debugging. Om te voorkomen dat hierbij geheime data gelekt wordt, wist de chip automatisch al het flash-geheugen bij het downgraden van RDP 1 naar 0.

**RDP 2: Geavanceerde aanvalstechnieken**

Vanaf RDP 2 wordt het een stuk moeilijker. We hebben geen debug-toegang, dus het is onmogelijk om het flash-geheugen te lezen of te schrijven. Ik heb er zelf geen ervaring mee, maar ik heb op het internet verscheidene keren gezien dat men zogenaamde **voltage-glitches** toepast. 

Bij voltage-glitching wordt op een bepaald moment in het opstartproces het voltage abrupt omlaag gegooid, wat ervoor zorgt dat de transistoren in de chip op dat moment niet kunnen schakelen. Als je een voltage-glitch toepast op het moment dat de bootloader het RDP-niveau uit de option bytes leest, kan het zijn dat de bootloader verkeerde bytes leest. Omdat de byte `0xCC` telt als RDP 2, `0x00` voor RDP 0 en alle andere waarden tellen voor RDP 1, zal de chip bij een goede voltage glitch iets anders dan `0xCC` lezen, en de RDP dus op 1 of 0 zetten. Wel is een voltage glitch erg lastig te doen, want er is gespecialiseerde apparatuur voor nodig.

Naast een voltage glitch las ik op internet ook verhalen van mensen die **UV-licht** heel geconcentreerd op een bepaald gedeelte van een chip konden laten schijnen om bepaalde bytes te flippen, maar daarvoor moesten ze eerst de bovenkant van de chip eraf schuren. Dit is ook geen huis-tuin-en-keuken klusje, maar het werkt dus wel.

> **Let op:** De NumWorks maakt (vooralsnog) gebruik van RDP 1, en het is dus gemakkelijk te downgraden naar RDP 0. Maar, met een software-update kan NumWorks op elk moment het RDP niveau "upgraden" naar RDP 2. Hoewel tijdens het updateproces het een en ander te veranderen is, maakt zo'n upgrade naar RDP 2 het ontgrendelen van de rekenmachine een stuk lastiger.

---

### Het unlock-script

Hier is het bestand `unlock120.run` wat gebruikt wordt voor het ontgrendelen van de rekenmachine (uitleg staat na de dubbele slash):

```bash
init
halt
stm32h7x option_write 0 0x44 0x1ff01ff0    // Zet het bootaddress op 0x1ff voor zowel boot1 als boot0 mode, om ervoor te zorgen dat de chip opstart naar de STM32 recovery mode
stm32h7x option_write 0 0x3C 0xFF          // Schrijf RDP 1
stm32h7x unlock 0                          // Hef de RDP op
```

---

### Hoe werkt het unlock-script?

Laten we regel voor regel bekijken wat dit script doet:

#### Regel 3: Bootaddress naar 0x1ff zetten

Het adres `0x1ff0000` is een speciaal geheugengebied in STM32 chips waar de zogenaamde "system bootloader" staat. Dit is een klein stukje software dat door STMicroelectronics zelf in de chip is geprogrammeerd tijdens de fabricage en niet gewist kan worden. Deze system bootloader kan communiceren via USB en maakt het mogelijk om firmware te uploaden zonder een externe debugger. Door het bootaddress naar `0x1ff` te schrijven, zorgen we ervoor dat de chip na het herstarten opstart in deze speciale modus in plaats van de normale bootloader van NumWorks.

#### Regel 4: RDP 1 schrijven

Dit lijkt vreemd: waarom schrijven we RDP 1 als we juist RDP 0 willen? Dit heeft te maken met hoe de STM32 unlock-functie werkt. Het unlock-commando op regel 5 downgradet het RDP-niveau met één stap. Als de chip op RDP 0 zou staan en we voeren unlock uit, zou dit proberen te downgraden naar RDP -1, wat niet bestaat en tot onvoorspelbaar gedrag leidt. Door expliciet RDP 1 te schrijven, weten we zeker dat de chip op RDP 1 staat voordat we unlocked. Dit is een veiligheidsmaatregel.

#### Regel 5: Unlock uitvoeren

Dit commando downgradet RDP 1 naar RDP 0 en wist tegelijkertijd automatisch het volledige interne flash-geheugen. Na deze stap is de chip ontgrendeld, maar volledig leeg. Er staat geen bootloader of firmware meer op.



---

### Communicatie via SWD

Dit script is een script voor de **OpenOCD** software. OpenOCD staat voor Open On-Chip Debugger, en is een toolkit voor het debuggen van STM32 en andere [microcontrollers](https://nl.wikipedia.org/wiki/Microcontroller). Het draait op een [Raspberry Pi 3](https://nl.wikipedia.org/wiki/Raspberry_Pi), dit is een minicomputer bij uitstek geschikt voor dit soort debug-taken, omdat er een aantal programmeerbare in- en uitgangen (GPIO) op de computer zelf zitten.

De communicatie tussen de Raspberry Pi en de NumWorks gebeurt via een protocol genaamd **[SWD (Serial Wire Debug)](https://en.wikipedia.org/wiki/JTAG#Serial_Wire_Debug)**. Dit is een debug-interface die door ARM is ontwikkeld en gebruikt slechts twee draden:
- **SWDIO** (voor data)
- **SWCLK** (voor het kloksignaal)
- Plus een **aardverbinding** (GND)

Via deze interface kan OpenOCD direct met de processor communiceren, registers uitlezen, geheugen schrijven, en de processor starten en stoppen. Dit is normaal gesproken bedoeld voor ontwikkelaars om hun code te debuggen, maar wij gebruiken het hier om de beveiligingsinstellingen aan te passen.

De Raspberry Pi is door middel van drie draadjes verbonden met de NumWorks, en daardoor doet OpenOCD zijn werk.



---

### Na het ontgrendelen

Nu is de chip in de rekenmachine ontgrendeld. Doordat OpenOCD ook het bootadres schreef naar `0x1ff`, start de rekenmachine op naar de STM32 system bootloader (ook wel **DFU-modus** genoemd: Device Firmware Update). In deze modus is het mogelijk om met de chip te communiceren via USB, de bootloader te updaten en de bootloader uit te lezen. 

We kunnen niet direct bij de firmware komen, omdat deze staat opgeslagen op een externe flash-chip. Het interne geheugen van de STM32 is namelijk gewist door het unlock-proces. Als we de firmware willen lezen of schrijven, moeten we eerst een bootloader op de rekenmachine programmeren die het externe flash-geheugen initialiseert. Deze bootloader zal dan de brug vormen tussen de computer en het flash-geheugen.

#### De bootloader extraheren

De officiële bootloader van NumWorks staat online: [Firmware download](https://my.numworks.com/firmwares/n0120/stable.dfu) *(je moet ingelogd zijn)*. Het is mogelijk vanaf hier een zogeheten **Device Firmware Update** bestand te downloaden. Dit bestand bevat alle bestanden (bootloader, firmware, userland, kernel) die nodig zijn om de rekenmachine te updaten. 

Voor de hack is het nodig om de bootloader uit het bestand te extraheren. Dit kan met `dfuse_extract.py` in de map `bootloader`. Dit kleine Python programmaatje haalt de verschillende blokken code uit het DFU bestand, en geeft ze terug als `.bin` bestanden. Een `.bin` bestand is een binair bestand, het zijn dus enkel enen en nullen.



---

### De bootloader patchen

We hebben nu dus de officiële bootloader van NumWorks in handen. We zouden deze kunnen flashen met OpenOCD of een online WebDFU-tool. Maar dat is een slecht idee, omdat de bootloader van NumWorks RDP 1 weer inschakelt en enkel geverifieerde firmware uit het geheugen laadt en opstart. Het is dus van belang dat we de bootloader patchen, en dat doen we door de nullen en enen die verantwoordelijk zijn voor de hierboven beschreven taken te overschrijven met nullen. 

#### Reverse engineering met Ghidra

Het is simpeler gezegd dan gedaan, omdat men niet zomaar kan weten welke code wat doet. Het binaire bestand bestaat uit [machinecode](https://nl.wikipedia.org/wiki/Machinetaal) - directe instructies voor de processor die voor mensen onleesbaar zijn. Tools als **[Ghidra](https://github.com/nationalsecurityagency/ghidra)** maken dit makkelijker. Ghidra is een reverse engineering tool ontwikkeld door de NSA (Amerikaanse National Security Agency) en kan de binaire code omzetten naar assembly-code, wat iets makkelijker te lezen is. Assembly is een lage programmeertaal die nog steeds heel dicht bij de hardware staat, maar tenminste leesbare instructies gebruikt zoals `LOAD`, `STORE`, en `JUMP` in plaats van pure enen en nullen.

Iemand moet dus door de assembly-code heen om te vinden waar de bootloader de RDP inschakelt en waar de handtekeningverificatie gebeurt. Deze stukken code kunnen dan vervangen worden door `NOP`-instructies (No Operation - doe niets) of door instructies die altijd "succesvol" teruggeven, zodat de verificatie altijd slaagt. 

#### Online patch-tool

Een Fransman heeft de bootloader voor een klein deel reverse engineered, en dezelfde Fransman heeft een webpagina gemaakt om de bootloader te patchen. Ik heb de webpagina vertaald naar het Engels en hij staat hier: **[Bootloader and kernel patch](https://lukashilverda.nl/numworks/patch.html)**.

Na het patchen krijgt u een `.bin` bestand terug en is het mogelijk om deze naar de rekenmachine te flashen. De gemakkelijkste manier is om dit te doen via [deze website](https://ti-planet.github.io/webdfu_numworks/n0110/). Het is mogelijk het `.bin` bestand te selecteren en te flashen met behulp van de **"Flash Internal"** knop.

Nu staat de gepatchte bootloader op de rekenmachine, en is het mogelijk om ook de external flash te beschrijven met firmware. Dit kan met dezelfde website, maar in plaats van "Flash Internal" dient men te kiezen voor **"Flash External"**.



---

## Conclusie

Deze hack laat zien hoe beveiligingsmechanismen in embedded systemen kunnen worden omzeild door een combinatie van hardware-toegang en kennis van de onderliggende architectuur. Het belangrijkste zwakpunt hier is dat NumWorks RDP niveau 1 gebruikt in plaats van niveau 2. Met RDP 1 is het mogelijk om de beveiliging uit te schakelen via een debug-interface, zij het met verlies van alle data.

### Toekomstperspectief

Als NumWorks in de toekomst zou upgraden naar RDP 2, zou deze methode niet meer werken zonder geavanceerde technieken zoals voltage glitching of UV-attacks. Het ontgrendelen zou dan een stuk lastiger worden en specialistische apparatuur vereisen.

### Alternatieve bootloaders

Het is ook mogelijk om in plaats van de bootloader van NumWorks zelf, een andere bootloader te gebruiken. Hier staat een [voorbeeld](https://github.com/lukashilverda/Numwork-N120-Crack). Dit is een fork van een andere repository, ik heb enkele dingen toegevoegd, zoals betere documentatie van de code. [Hier](https://github.com/lukashilverda/Numwork-N120-Crack/releases) is het `.bin` bestand te downloaden. Deze bootloader zal de LED op de rekenmachine laten rainbow cyclen.


---