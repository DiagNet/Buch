#import "@preview/htl3r-da:2.0.0" as htl3r

#show: htl3r.diplomarbeit.with(
  title: "DiagNet",
  subtitle: "Test-Driven-Networking leicht gemacht",
  department: "ITN",
  school-year: "2025/26",
  authors: (
    (
      name: "Karun Sandhu",
      supervisor: "Harald Zainzinger",
      role: "Projektleiter",
    ),
    (
      name: "Luka Pacar",
      supervisor: "Harald Zainzinger",
      role: "Stv. Projektleiter",
    ),
    (
      name: "Benedikt Theuretzbachner",
      supervisor: "Christian Schöndorfer",
      role: "Mitarbeiter",
    ),
    (
      name: "Danijel Stamenkovic",
      supervisor: "Christian Schöndorfer",
      role: "Mitarbeiter",
    ),
  ),
  supervisor-incl-ac-degree: (
    "Prof. Dipl.-Ing. Dr. Harald Zainzinger",
    "AV Prof. Dipl.-Ing. Christian Schöndorfer",
  ),
  sponsors: (
    "Cancom SE",
  ),
  abstract-german: [#include "text/kurzfassung.typ"],
  abstract-english: [#include "text/abstract.typ"],
  date: datetime.today(),
  print-ref: false,
  generative-ai-clause: none,
  abbreviation: {
    let data = yaml("abbr.yml")
    for (key, value) in data {
      if type(value) != dictionary { continue }

      // Handle description
      if "description" in value {
        data.at(key).description = eval(value.description, mode: "markup")
      }

      // Handle full form
      if "full" in value {
        data.at(key).full = eval(value.full, mode: "markup")
      }

      // Handle short and long forms (singular/plural)
      for field in ("short", "long") {
        if field in value and type(value.at(field)) == dictionary {
          for form in ("singular", "plural") {
            if form in value.at(field) {
              data.at(key).at(field).at(form) = eval(
                value.at(field).at(form),
                mode: "markup",
              )
            }
          }
        }
      }
    }
    data
  },
  bibliography-content: bibliography(
    "refs.yml",
    full: false,
    title: [Literaturverzeichnis],
  ),
)

#include "chapters/01_architecture_design.typ"   // Danijel
#include "chapters/02_routing_infra.typ"         // Luka
#include "chapters/03_switching_infra.typ"       // Danijel
#include "chapters/04_firewalls_security.typ"    // Benedikt
#include "chapters/05_dev_environment.typ"       // Karun
#include "chapters/06_django_framework.typ"      // Karun
#include "chapters/07_interfaces_automation.typ" // Benedikt
#include "chapters/08_data_security.typ"         // Karun
#include "chapters/09_test_engine_arch.typ"      // Luka
#include "chapters/10_dynamic_forms.typ"         // Luka
#include "chapters/11_routing_tests.typ"         // Luka
#include "chapters/12_switching_tests.typ"       // Danijel
#include "chapters/13_frontend_ux.typ"           // Karun
#include "chapters/14_data_visualization.typ"    // Danijel
#include "chapters/15_containerization.typ"      // Karun
#include "chapters/16_cicd_automation.typ"       // Karun
