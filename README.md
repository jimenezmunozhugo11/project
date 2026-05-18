# ⚽ Football Project — European Soccer Database

> Final project for the **Data Engineering with dbt and Snowflake** course.  
> Use case: **European football analysis** based on the European Soccer Database (Kaggle).  
> Data source: SQLite database containing match results, teams, players, and leagues from 11 European countries between 2008 and 2016.

This repository is a **complete and fully functional** dbt project that applies everything learned throughout the course: sources, staging, marts (star schema), tests, seeds, macros, and snapshots. It is organized into two transformation layers on Snowflake: a Silver layer (staging views) and a Gold layer (dimensional and fact tables).

---

## 📑 Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Data Source](#data-source)
- [Data Model](#data-model)
- [Initial Setup](#initial-setup)
- [How to Run the Project](#how-to-run-the-project)
- [Additional Resources](#additional-resources)

---

## Prerequisites

Before running this project, make sure you have:

- ✅ Access to the course **Snowflake** account
- ✅ Your assigned role with permissions on the course warehouse
- ✅ Your three **DEV** databases created in Snowflake:
  - `DEV_BRONZE_SOCCER_DB`
  - `DEV_SILVER_SOCCER_DB`
  - `DEV_GOLD_SOCCER_DB`
- ✅ The **`DBT_ENVIRONMENTS`** environment variable configured in your dbt Cloud profile pointing to `DEV` (without the `_SILVER_SOCCER_DB` or `_GOLD_SOCCER_DB` suffix)
- ✅ The `EUROPEAN_SOCCER_DATABASE` schema already populated with the course data in your Bronze database

---

## Project Structure

```text
football_project/
├── README.md                               ← This file
├── dbt_project.yml                         ← Central project configuration
├── packages.yml                            ← External dependencies (dbt_utils, ...)
├── package-lock.yml
├── .gitignore
│
├── models/
│   ├── staging/                            ← Silver layer (views)
│   │   ├── _raw__sources.yml               ← Source declarations (loaded SQLite tables)
│   │   ├── _raw__models.yml                ← Staging tests and documentation
│   │   ├── stg_raw__country.sql
│   │   ├── stg_raw__league.sql
│   │   ├── stg_raw__season.sql
│   │   ├── stg_raw__team.sql
│   │   ├── stg_raw__team_attributes.sql
│   │   ├── stg_raw__match.sql
│   │   ├── stg_raw__player.sql
│   │   ├── stg_raw__player_attributes.sql
│   │
│   └── marts/                              ← Gold layer (tables — star schema)
│       ├── _core__models.yml               ← Marts tests and documentation
│       ├── dim_date.sql                    ← Calendar dimension
│       ├── dim_team.sql                    ← Team dimension
│       ├── dim_league.sql                  ← League dimension
│       ├── dim_season.sql                  ← Season dimension
│       ├── dim_player.sql                  ← Player dimension (biographical data)
│       ├── fct_match_result.sql            ← Fact table at match grain
│       └── fct_team_season_stats.sql       ← Fact table at team-season grain
│
├── analyses/                               ← Ad-hoc analytical queries
├── macros/                                 ← Reusable Jinja macros
├── seeds/                                  ← Static reference tables (CSV)
├── snapshots/                              ← Change tracking over time (SCD)
└── tests/                                  ← Custom singular tests
```

---

## Data Source

The project uses the **European Soccer Database** from Kaggle (`hugomathien/soccer`), a SQLite database containing European football data between the 2008/2009 and 2015/2016 seasons.

### Available Source Tables

| Table | Description |
|---|---|
| `Country` | League countries (11 European leagues) |
| `League` | Leagues for each country |
| `Match` | Matches played with results, dates, and lineups |
| `Team` | Participating teams |
| `Team_Attributes` | Tactical team attributes by season (play style, pressure, etc.) |
| `Player` | Player biographical data (name, birth date, height, weight) |
| `Player_Attributes` | Player technical attributes by date |

> **Note:** FIFA rating fields (`overall_rating`, `potential`, `player_fifa_api_id`) and XML lineup data are not included.

---

## Data Model

The project implements a **star schema** in the Gold layer with two fact tables and five dimensions.

### Dimensions

| Model | Grain | Description |
|---|---|---|
| `dim_date` | Date | Generated calendar dimension |
| `dim_team` | Team | Team name and metadata |
| `dim_league` | League | League and associated country |
| `dim_season` | Season | Season identifier (e.g. `2012/2013`) |
| `dim_player` | Player | Biographical data (name, height, weight, birth date) |

### Fact Tables

| Model | Grain | Description |
|---|---|---|
| `fct_match_result` | Match | Result, goals, home/away teams, league, and season |
| `fct_team_season_stats` | Team × Season | Aggregated statistics: matches played, wins, draws, losses, goals scored/conceded, points |

---

## Initial Setup

### 1️⃣ `DBT_ENVIRONMENTS` Environment Variable

Go to your **Profile Settings → Credentials → this project** in dbt Cloud and configure:

```bash
DBT_ENVIRONMENTS = DEV
```

This variable controls which databases the models point to:

- Staging → `DEV_SILVER_SOCCER_DB.EUROPEAN_SOCCER_DATABASE`
- Marts → `DEV_GOLD_SOCCER_DB.EUROPEAN_SOCCER_DATABASE`

### 2️⃣ Install Packages

```bash
dbt deps
```

### 3️⃣ Load Seeds (if applicable)

```bash
dbt seed
```

### 4️⃣ Validate the Connection

```bash
dbt debug
```

If everything is correctly configured, you should see `All checks passed!`.

---

## How to Run the Project

### Full Build (recommended)

```bash
dbt build
```

`dbt build` executes in dependency order: `seed → run → test`. If any test fails, downstream models are not built.

### Commands by Layer

```bash
# Only the staging layer (views in SILVER)
dbt run --select staging

# Only the marts layer (dimensions and facts in GOLD)
dbt run --select marts

# A specific model and all its parents
dbt run --select +fct_match_result

# A specific model and all its children
dbt run --select stg_match+
```

### Tests

```bash
dbt test                          # All tests
dbt test --select staging         # Only staging layer tests
dbt test --select marts           # Only marts layer tests
dbt test --select fct_match_result
```

### Documentation

```bash
dbt docs generate
dbt docs serve    # In dbt Core. In dbt Cloud: "View Docs" button
```

### Snapshots

```bash
dbt snapshot      # All snapshots
```

---

## Additional Resources

- https://docs.getdbt.com/
- https://docs.getdbt.com/best-practices
- https://www.kaggle.com/datasets/hugomathien/soccer
- https://github.com/dbt-labs/dbt-utils

---

**Author**: Hugo Jiménez Muñoz · Final Project for the Data Engineering Course