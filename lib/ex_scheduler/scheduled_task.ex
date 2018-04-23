defmodule ExScheduler.ScheduledTask do
  @moduledoc """
  Module responsible to isolate in a process, each recurring event declared
  with ExScheduler.Schedule.
  """

  defmodule State do
    @moduledoc false
    defstruct schedule: nil, runs: 0, failures: 0, total_failures: 0, last_completed_in: nil
  end

  use GenServer
  require Logger

  @doc "Starts a scheduled task process"
  @spec start_link(list()) :: GenServer.on_start
  def start_link(schedule), do: GenServer.start_link(__MODULE__, schedule)

  @doc false
  def init(%{first_in: first_in} = schedule) do
    Process.send_after(self(), :run, first_in)

    {:ok, %State{schedule: schedule}}
  end

  @doc "Returns statistcs for the given task process"
  @spec stats(pid()) :: %{runs: integer(), failures: integer(), last_completed_in: nil | number()}
  def stats(pid), do: GenServer.call(pid, :stats)

  # callbacks

  def handle_call(:stats,
                  _from,
                  %{schedule: %{name: name},
                    runs: runs,
                    failures: failures,
                    last_completed_in: last_completed_in} = state) do
    {:reply, %{name: name, runs: runs, failures: failures, last_completed_in: last_completed_in}, state}
  end

  def handle_cast(:run, %{schedule: %{interval: interval} = schedule} = state) do
    with {:noreply, _} = ret <- schedule |> run |> handle_run(state) do
      Process.send_after(self(), :run, interval)
      ret
    end
  end

  def handle_info(:run, state), do: handle_cast(:run, state)

  defp handle_run({:ok, %{completed_in: time}}, %{runs: runs} = state) do
    {:noreply, %State{state | runs: runs + 1, failures: 0, last_completed_in: time}}
  end
  defp handle_run({:error, error}, %{schedule: %{module: mod, max_failures: max_failures}, failures: failures} = state)
  when failures + 1 >= max_failures do
    Logger.error "[#{inspect mod}] scheduled task failed with: #{inspect error}, state: #{inspect state} "

    {:stop, :normal, state}
  end
  defp handle_run({:error, _error}, %{runs: runs, failures: failures, total_failures: total_failures} = state) do
    {:noreply, %State{state | runs: runs + 1, failures: failures + 1, total_failures: total_failures + 1}}
  end

  defp run(%{id: id, module: module} = _schedule) do
    (fn -> apply module, :handle_task, [id] end) |> timed_call
  end

  defp timed_call(f) do
    {:ok, %{completed_in: ((f |> :timer.tc |> elem(0)) / 1_000_000)}}
  rescue
    e -> {:error, e}
  end
end
