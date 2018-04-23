# ExScheduler

This project provides a way to run tasks in an interval basis.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_scheduler` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_scheduler, "~> 0.1.0"}
  ]
end
```

## Getting Started

After installation you can use the `ExScheduler` module and define the scheduled tasks using the `schedule` macro.

### Example

```elixir
defmodule YourApp.Schedules.Developer do
  use ExScheduler

  schedule every: {6, :hours} do
    Developer.eat(:pizza)
  end

  schedule every: :hour, first_in: {20, :minutes} do
    Developer.drink(:coffee)
  end
end
```

### Authors

- Dimitrios Zorbas (*[Zorbash](https://github.com/Zorbash)*)
- Luiz Varela (*[LuizVarela](https://github.com/Luizvarela)*)
