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
    "Prof. Dipl.-Ing. Harald Zainzinger",
    "Prof. Dipl.-Ing. Christian Schöndorfer",
  ),
  sponsors: (
    "Cancom SE",
  ),
  abstract-german: [#include "text/kurzfassung.typ"],
  abstract-english: [#include "text/abstract.typ"],
  date: datetime.today(),
  print-ref: false,
  generative-ai-clause: none,
  abbreviation: yaml("abbr.yml"),
  bibliography-content: bibliography(
    "refs.yml",
    full: false,
    title: [Literaturverzeichnis],
  ),
)

// #include "chapter/example.typ"
#include "chapter/test_framework.typ"
#include "chapter/pyats.typ"
