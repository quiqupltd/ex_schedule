# ExSchedule

[![Build Status](https://travis-ci.org/quiqupltd/ex_schedule.svg?branch=master)](https://travis-ci.org/quiqupltd/ex_schedule)
[![Package Version](https://img.shields.io/hexpm/v/ex_schedule.svg)](https://hex.pm/packages/ex_schedule)
[![Coverage Status](https://coveralls.io/repos/github/quiqupltd/ex_schedule/badge.svg?branch=master)](https://coveralls.io/github/quiqupltd/ex_schedule?branch=master)

This project provides a way to run tasks in an interval basis.

## Documentation

* [hexdocs][hexdocs]

## Installation

The package can be installed by adding `ex_schedule` to your list of dependencies in `mix.exs`:


```elixir
def deps do
  [
    {:ex_schedule, "~> 0.1"}
  ]
end
```

## Getting Started

After installation you can use the `ExSchedule` module and define the scheduled tasks using the `schedule` macro.

### Usage

Define a schedule module with recurring tasks:

```elixir
defmodule YourApp.Schedules.Developer do
  use ExSchedule

  schedule every: {6, :hours} do
    Developer.eat(:pizza)
  end

  schedule every: :hour, first_in: {20, :minutes} do
    Developer.drink(:coffee)
  end
end
```

Add the module to your supervision tree:

```elixir
defmodule YourApp.Application do
  use Application

  import Supervisor.Spec

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    children = [supervisor(YourApp.Schedules.Developer, [[name: :developer_schedule]])]

    Supervisor.start_link(children, opts)
  end
end
```

### Authors

- Dimitrios Zorbas (*[Zorbash](https://github.com/Zorbash)*)
- Luiz Varela (*[LuizVarela](https://github.com/Luizvarela)*)

## License

Copyright (c) 2018 Quiqup LTD, MIT License.
See [LICENSE.txt](https://github.com/quiqupltd/ex_schedule/blob/master/LICENSE.txt) for further details.

[hexdocs]: https://hexdocs.pm/ex_schedule/0.1.0/ExSchedule.html
