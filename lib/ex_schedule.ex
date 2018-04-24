defmodule ExSchedule do
  @moduledoc """
  Module providing a way to declare actions happening on an interval basis.

  Defining a schedule

  ```
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

  Adding the schedule to the supervision tree

  ```
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

  Supported options:

  # Intervals
  `every`: The interval on which to run the task

  `first_in`: How much time to wait before the first run, defaults to 0

  Examples

  ```
  schedule every: :millisecond, do: Task.execute # every millisecond
  schedule every: :second, do: Task.execute      # every second
  schedule every: :minute, do: Task.execute      # every minute
  schedule every: :hour, do: Task.execute        # every hour
  schedule every: :day, do: Task.execute         # every day

  schedule every: {2, :milliseconds}, do: Task.execute # every 2 milliseconds
  schedule every: {2, :seconds}, do: Task.execute      # every 2 seconds
  schedule every: {2, :minutes}, do: Task.execute      # every 2 minutes
  schedule every: {2, :hours}, do: Task.execute        # every 2 hours
  schedule every: {2, :days}, do: Task.execute         # every 2 days

  schedule every: {2, :hours}, first_in: 0, do:
    Task.execute # every 2 hours first in 0 seconds
  end

  schedule every: {2, :hours}, first_in: {20, :minutes} do
    Task.execute # every 2 hours first in 20 minutes
  end
  ```

  # Failure handling
  `:max_failures` - Number of times to fail for the task process to be restarted, defaults to `:infinity`

  Examples

  ```
  schedule every: {2, :days}, max_failures: 5, do: something
  ```
  """

  defmacro __using__(_opts) do
    quote location: :keep do
      require Logger

      Module.register_attribute(__MODULE__, :schedules, accumulate: true)

      use Supervisor

      import ExSchedule

      @doc "Starts the Schedule with the given arguments"
      @spec start_link(list()) :: GenServer.on_start()
      def start_link(opts) do
        with namespace <- normalize_namespace(opts[:namespace]) do
          Supervisor.start_link(
            __MODULE__,
            put_in(opts[:namespace], namespace),
            name: name(opts[:name], namespace)
          )
        end
      end

      @doc false
      def init(opts) do
        schedules() |> Enum.map(&child_spec/1) |> supervise(strategy: :one_for_one)
      end

      @doc "Returns the namespace of the schedule"
      def namespace do
        self() |> Process.info([:links]) |> Access.get(:links) |> Enum.at(0) |> namespace
      end

      def namespace(server) when is_pid(server) do
        server
        |> Process.info([:registered_name])
        |> Access.get(:registered_name)
        |> namespace
      end

      def namespace(server) when is_atom(server) do
        size = __MODULE__ |> to_string |> byte_size

        case server |> to_string do
          <<_module::bytes-size(size)>> <> "." <> namespace -> normalize_namespace(namespace)
          _ -> nil
        end
      end

      ### Callbacks

      @doc false
      def handle_call(:state, _from, state), do: {:reply, state, state}

      defp normalize_namespace(ns) when is_bitstring(ns), do: String.to_atom(ns)
      defp normalize_namespace(ns), do: ns

      defp child_spec(schedule) do
        worker(ExSchedule.ScheduledTask, [schedule], id: schedule.id)
      end

      defp name(nil, nil), do: __MODULE__
      defp name(nil, ns), do: :"#{__MODULE__}.#{ns}"
      defp name(name, _namespace), do: name

      @before_compile ExSchedule
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    quote do
      @doc "Returns the list of scheduled tasks"
      @spec schedules() :: list(map())
      def schedules, do: unquote(Module.get_attribute(env.module, :schedules))
    end
  end

  @doc "A macro that defines a recurrent task"
  @spec schedule(list(), list()) :: tuple()
  defmacro schedule(options, do: expression) do
    id = make_ref() |> inspect

    quote do
      def handle_task(unquote(id)), do: unquote(expression)

      @schedules Macro.escape(%{
                   id: unquote(id),
                   module: __MODULE__,
                   name: unquote(options)[:name],
                   max_failures: unquote(options)[:max_failures] || :infinity,
                   interval: ExSchedule.interval(unquote(options)[:every]),
                   first_in: ExSchedule.interval(unquote(options)[:first_in]) || 0
                 })
    end
  end

  def interval(n) when n in [nil, 0], do: 0
  def interval(n) when is_number(n), do: n * 1000
  def interval({_, :millisecond}), do: 1
  def interval({n, :milliseconds}), do: n
  def interval(:second), do: interval({1, :seconds})
  def interval(:minute), do: interval({1, :minutes})
  def interval(:hour), do: interval({1, :hours})
  def interval(:day), do: interval({24, :hours})

  def interval({1, duration}) when duration in [:second, :minute, :hour, :day] do
    apply(__MODULE__, :interval, [duration])
  end

  def interval({n, duration}) when duration in [:seconds, :minutes, :hours] do
    apply(:timer, duration, [n])
  end
end
