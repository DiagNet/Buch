#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")
== Datenvisualisierung <data_visualization>

Ein Werkzeug für die Prüfung von Netzwerken ist nur dann wirklich nützlich, wenn die Ergebnisse verständlich und übersichtlich dargestellt werden. Bei DiagNet wurde deshalb auf eine Strategie gesetzt, welche die Informationen auf verschiedenen Ebenen aufbereitet. Ein Dashboard gibt einen schnellen Überblick über das gesamte Netz, während man in den Detailansichten jeden einzelnen Testschritt genau nachvollziehen kann. Für die Dokumentation lassen sich zudem PDF-Berichte erstellen. Die gesamte Oberfläche wurde mit #htl3r.long[htmx] umgesetzt @htmx-docs, wodurch die Seite schnell reagiert, ohne dass man ein schwerfälliges JavaScript-Framework benötigt hätte.

=== Speicherung und Abfrage der Daten

Die Ergebnisse der Tests werden in einer Datenbank gespeichert. Damit die Weboberfläche auch bei vielen Daten flüssig bleibt, müssen die Abfragen optimiert werden. In Django wurde hierfür die Funktion `prefetch_related` genutzt, welche alle zusammengehörigen Daten in wenigen Schritten aus der Datenbank lädt.

```python
testgroups = TestGroup.objects.prefetch_related(
    Prefetch(
        "testcases",
        queryset=TestCase.objects.prefetch_related(
            Prefetch(
                "results",
                queryset=TestResult.objects.order_by("-created_at"),
            )
        ),
    )
).all()
```

Durch dieses Vorgehen wird verhindert, dass für jedes einzelne Element auf der Seite eine eigene Anfrage an die Datenbank geschickt werden muss. Dies spart Zeit und sorgt dafür, dass das Dashboard auch bei hunderten Testergebnissen sofort geladen wird.

=== Das Dashboard

Das Dashboard bildet das Herzstück der Benutzeroberfläche und führt die in Kapitel @frontend_ux beschriebenen Prinzipien für die Benutzererfahrung zusammen. Es ist der zentrale Punkt für den Techniker, an dem alle Testgruppen und deren aktueller Status angezeigt werden. Sobald sich ein Status ändert, wird dieser Bereich der Seite automatisch aktualisiert, ohne dass man die Seite neu laden muss.

==== Übersicht mit KPI-Karten
Im oberen Teil des Dashboards befinden sich Karten für die wichtigsten Kennzahlen. Man sieht dort auf einen Blick die Gesamtzahl der Tests sowie die Anzahl der bestandenen, fehlgeschlagenen und übersprungenen Prüfungen. Eine farbliche Kennzeichnung in Grün, Rot und Grau hilft dabei, den Zustand des Systems sofort einzuschätzen. Diese Werte werden direkt über Datenbank-Abfragen in Django berechnet.

==== Grafische Darstellung mit Diagrammen
Unter den Kennzahlen werden die Ergebnisse in Balkendiagrammen visualisiert. Man nutzt hierfür die Bibliothek #htl3r.long[chartjs] @chartjs-docs. Ein Diagramm zeigt den Zustand der verschiedenen Testgruppen an, während ein anderes Diagramm die Ergebnisse auf Ebene der einzelnen Testfälle aufschlüsselt. So lassen sich Trends erkennen, zum Beispiel ob ein bestimmter Fehler im Netz immer wieder auftritt.

=== Detailansicht der Testgruppen

Die Testgruppen werden in einer einklappbaren Liste dargestellt. Wenn man eine Gruppe öffnet, werden die zugehörigen Testfälle nachgeladen. Über verschiedene Schaltflächen kann man einen Testlauf starten, einen Vergleich mit früheren Ergebnissen öffnen oder einen Bericht exportieren. Der Zugriff auf diese Funktionen ist über ein Berechtigungssystem geschützt.

=== Aktualisierung in Echtzeit

Während ein Test im Hintergrund läuft, wird der Status auf dem Dashboard in Echtzeit aktualisiert. Hierfür wurde ein Mechanismus in HTMX genutzt, der auf Ereignisse im Browser reagiert. Sobald ein Test abgeschlossen ist, schickt der Server ein Signal an das Frontend, woraufhin die betroffenen Teile der Seite neu geladen werden. Man hat sich bewusst gegen WebSockets entschieden, um die technische Komplexität gering zu halten, da die gewählte Lösung für diesen Anwendungsfall völlig ausreicht.

=== Vergleich von Testläufen

In DiagNet gibt es die Möglichkeit, zwei aufeinanderfolgende Testläufe direkt miteinander zu vergleichen. Man sieht in einer Tabelle sofort, welche Tests sich verbessert oder verschlechtert haben. Änderungen im Status werden farblich hervorgehoben, damit Rückschritte in der Konfiguration nach einer Änderung am Netz sofort auffallen.

=== Erstellung von PDF-Berichten

Für die Dokumentation von Audits wurde eine Funktion zur Erstellung von PDF-Berichten eingebaut. Hierfür wird die Bibliothek ReportLab genutzt @reportlab-docs. Ein solcher Bericht enthält ein Deckblatt mit den wichtigsten Kennzahlen, ein Diagramm zur Übersicht und eine detaillierte Liste aller geprüften Testfälle. Die Berichte werden direkt auf dem Server generiert und stehen danach als Download zur Verfügung. Dies stellt sicher, dass die Dokumentation immer das gleiche professionelle Layout besitzt, egal mit welchem Browser man DiagNet gerade nutzt.
