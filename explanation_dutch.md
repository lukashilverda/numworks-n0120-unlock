## Uitleg bij het ontgrendelen van de rekenmachine
Hoewel het hacken van de rekenmachine niet zo simpel is, is het van belang dat de beveiliging nog wat verder wordt opgeschroefd. In dit document beshcirjf ik hoe ik de hack heb kunnen doen, maar eerst even wat voorkennis:

## Het opstartproces van de rekenmachine

Het opstarten van de rekenmachine gebeurt in grofweg 2 stappen. 

1. De rekenmachine start op, en er wordt een klein programmaatje genaamd de bootloader ingeladen en uitgevoerd. Dit programmaatje doet op de NumWorks een aantal dingen:

Hardware initialiseren (beeldscherm, flash-geheugen)
Checken of de firmware die op de rekenmachine staat valide is
De firmware op de rekenmachine starten

De eerste stap is het initialseren van de hardware. De QSPI-flash (het opslaggeheugen) wordt verbonden, en de bootloader kijkt waar hij de firmware in dat geheugen kan vinden. Daarnaast activeert de bootloader RDP (Readout Protection), om te voorkomen dat iemand in het geheugen kan kijken.

Vervolgens kijkt de bootloader in de firmware, om de firmware te valideren. Het valideren van de software gebeurt op basis van een "digitale handtekening". Aan de structuur de software kan de bootloader "zien" of deze officiëel is. 

Daarna start de rekenmachine de firmware uit een van de twee slots, als deze geldig zijn. Mocht geen enkele firmware door de validatiecheck komen, dan toont de rekenmachine het recovery-modus scherm.

## Het laden van de eigen firmware

Om eigen firmware te kunnen laden, moeten we in het geheugen kunnen kijken. En dat niet alleen, we moeten het ook kunnen overschrijven. Dat is simpeler gezegd dan gedaan, maar het bestaat uit deze stappen:

### RDP uitzetten
Eigen bootloader en firmware programmeren
Bootloader en firmware op de rekenmachine zetten

RDP bestaat in 3 niveaus:
0: Geen beveiliging
1: Het is mogelijk om debug-toegang te krijgen, maar bij het lezen/schrijven naar het geheugen wordt het geheugen compleet gewist
2: Debug toegang is uit, het is niet eens mogelijk om te verbinden met de rekenmachine

Idealiter hebben we dus RDP 0. We kunnen hier komen vanaf RDP 1 door debug toegang te krijgen (en de flash te gaan lezen/schrijven) en in de option bytes van de chip de bytes van RDP 1 te overschrijven met 0. 

Vanaf RDP 2 wordt het een stuk moeilijker. We hebben geen debug toegang, dus het is onmogelijk om het flash geheugen te lezen of te schrijven. Ik heb er zelf geen ervaring mee, maar ik heb op het internet verscheidene keren gezien dat men zogenaamde voltage-glitches toepast. Bij voltage-glitching wordt op een bepaald moment in het opstartproces het voltage abrupt omlaag gegooid, wat er voor zorgt dat de transistoren in de chip op dat moment niet kunnen schakelen. Als je een voltage-glitch toepast op het moment dat de bootloader het RDP-niveau uit de option bytes leest, kan het zijn dat de bootloader verkeerde bytes leest. Omdat de byte 0xCC telt als RDP 2, 0x00 voor RDP 0 en alle andere waarden tellen voor RDP 1, zal de chip bij een goede voltage glitch iets anders dan 0xCC lezen, en de RDP dus op 1 of 0 zetten. Wel is een voltage glitch erg lastig te doen, want er is gespecialiseerde apparatuur voor nodig. 

Naast een voltage glitch las ik op internet ook verhalen van mensen die UV-licht heel geconcentreerd op een bepaald gedeelte van een chip konden laten schijnen om bepaalde bytes te flippen, maar daarvoor moesten ze eerst de bovenkant van de chip eraf schuren. Dit is ook geen huis-tuin-en-keuken klusje, maar het werkt dus wel.

De NumWorks maakt (vooralsnog) gebruik van RDP 1, en het is dus gemakkelijk te downgraden naar RDP 0. Maar, met een software-update kan NumWorks op elk moment het RDP niveau "upgraden" naar RDP 2. Hoewel tijdens het updateproces het een en ander te veranderen is, maakt zo'n upgrade naar RDP 2 het ontgrendelen van de rekenmachine een stuk lastiger. 

Hier is het bestand "unlock120.run" wat gebruikt wordt voor het ontgrendelen van de GR (uilteg staat na de dubbele slash):
```
init
halt
stm32h7x option_write 0 0x44 0x1ff01ff0    // Zet het bootaddress op 0x1ff voor zowel boot1 als boot0 mode, om ervoor te zorgen dat de chip opstart naar de STM32 recovery mode
stm32h7x option_write 0 0x3C 0xFF          // Schrijf RDP 1
stm32h7x unlock 0                          // Hef de RDP op
```

Dit script is een script voor de OpenOCD software. OpenOCD staat voor Open On-Chip Debugger, en is een toolkit voor het debuggen van STM32 en andere microcontrollers. Het draait op een Raspberry Pi 3 (https://nl.wikipedia.org/wiki/Raspberry_Pi), dit is een minicomputer bij uitstek geschikt voor dit soort debug taken, omdat er een aantal programmeerbare in- en uitgangen (GPIO) op de computer zelf zitten. De Raspberry Pi is door middel van drie draadjes verbonden met de NumWorks, en daardoor doet OpenOCD zijn werk.