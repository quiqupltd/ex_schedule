defmodule ExScheduleTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule TestSchedule do
    use ExSchedule

    schedule name: :tight_schedule, every: {100, :milliseconds} do
      with proxy <- Process.whereis(:schedule_test_proxy) do
        if proxy, do: send(proxy, :every_100ms_called)
      end
    end

    schedule every: :day, first_in: {0, :seconds} do
      with proxy <- Process.whereis(:schedule_test_proxy) do
        if proxy, do: send(proxy, :every_day_first_in_0)
      end
    end

    schedule every: :day, first_in: {300, :milliseconds} do
      with proxy <- Process.whereis(:schedule_test_proxy) do
        if proxy, do: send(proxy, :every_day_first_in_300ms)
      end
    end

    schedule every: :day, first_in: {0, :seconds} do
      with proxy <- Process.whereis(:schedule_test_proxy) do
        if proxy, do: send(proxy, {:namespace, namespace()})
      end
    end

    schedule every: :day, first_in: {0, :seconds} do
      with proxy <- Process.whereis(:schedule_test_proxy) do
        if proxy, do: send(proxy, :every_day_max_failures)
      end
    end

    schedule name: :failing, every: {100, :milliseconds}, max_failures: 4 do
      raise "Goodbye cruel world"
    end

    schedule name: :failing_indefinitely, every: {100, :milliseconds} do
      raise "Goodbye cruel world"
    end
  end

  def proxy(pid) do
    receive do
      message ->
        send(pid, message)
        proxy(pid)
    end
  end

  alias TestSchedule, as: Subject

  setup do
    if Process.whereis(:test_schedule), do: Process.unregister(:test_schedule)

    __MODULE__
    |> spawn_link(:proxy, [self()])
    |> Process.register(:schedule_test_proxy)

    on_exit(fn ->
      if Process.whereis(:schedule_test_proxy), do: Process.unregister(:schedule_test_proxy)
      if Process.whereis(:test_schedule), do: Process.unregister(:test_schedule)
    end)
  end

  describe "schedules/0" do
    test "returns the List of defined schedules" do
      expected =
        [
          %{interval: 100, first_in: 0},
          %{interval: 86_400_000, first_in: 0},
          %{interval: 86_400_000, first_in: 300},
          %{interval: 86_400_000, first_in: 0},
          %{interval: 86_400_000, first_in: 0},
          %{interval: 100, first_in: 0},
          %{interval: 100, first_in: 0}
        ]
        |> Enum.reverse()

      assert Subject.schedules() |> Enum.map(&Map.take(&1, [:interval, :first_in])) == expected
    end

    test "sets default :max_failures to :infinity" do
      assert [%{max_failures: :infinity} | _] = Subject.schedules() |> Enum.reverse()
    end
  end

  describe "start_link/1" do
    test "returns a Tuple" do
      name = generate_name(Subject)
      {:ok, scheduler} = Subject.start_link(name: name)

      assert is_pid(scheduler)
    end

    test "does not define handlers for undefined schedules" do
      assert_raise FunctionClauseError, fn -> Subject.handle_task(:undefined) end
    end

    test "defines handlers for all defined schedules" do
      Subject.schedules() |> Enum.map(& &1.id) |> Enum.each(&Subject.handle_task(&1))
    rescue
      e in RuntimeError -> %{message: "Goodbye cruel world"} = e
    end

    test "when name is given it registers the process with it" do
      name = generate_name(Subject)

      {:ok, scheduler} = Subject.start_link(name: name)

      scheduler_name =
        scheduler
        |> Process.info(:registered_name)
        |> elem(1)

      assert scheduler_name == name
    end

    test "when name is not given it registers the process with the module" do
      {:ok, scheduler} = Subject.start_link([])

      scheduler_name =
        scheduler
        |> Process.info(:registered_name)
        |> elem(1)

      assert scheduler_name == ExScheduleTest.TestSchedule
    end

    test "when name and namespace are given it registers with the name" do
      name = generate_name(Subject)

      {:ok, scheduler} = Subject.start_link(name: name, namespace: "namespace")

      scheduler_name =
        scheduler
        |> Process.info(:registered_name)
        |> elem(1)

      assert scheduler_name == name
    end

    test "when namespace is given it registers with the module and the namespace" do
      namespace = generate_name(Subject)

      {:ok, scheduler} = Subject.start_link(namespace: namespace)

      name = :"#{ExScheduleTest.TestSchedule}.#{namespace}"

      scheduler_name =
        scheduler
        |> Process.info(:registered_name)
        |> elem(1)

      assert scheduler_name == name
    end
  end

  describe "namespace/0" do
    test "returns the supervisor namespace" do
      namespace = generate_name(Subject)

      {:ok, _scheduler} = Subject.start_link(namespace: namespace)

      receive do
        {:namespace, ns} -> assert ns == namespace
      after
        100 -> raise "Did not receive the namespace"
      end
    end

    test "with a string namespace returns the supervisor namespace as an Atom" do
      namespace = generate_name(Subject)

      {:ok, _scheduler} = Subject.start_link(namespace: namespace)

      receive do
        {:namespace, ns} -> assert ns == namespace
      after
        100 -> raise "Did not receive the namespace"
      end
    end
  end

  describe "namespace/1" do
    test "with a PID returns the correct namespace" do
      namespace = generate_name(Subject)

      {:ok, scheduler} = Subject.start_link(namespace: namespace)

      assert scheduler |> Subject.namespace() == namespace
    end

    test "with a process name returns the correct namespace" do
      namespace = generate_name(Subject)

      {:ok, scheduler} = Subject.start_link(namespace: namespace)
      name = Process.info(scheduler, [:registered_name])[:registered_name]

      assert name |> Subject.namespace() == namespace
    end
  end

  describe "scheduling" do
    test "links a child process for each schedule" do
      namespace = generate_name(Subject)
      {:ok, scheduler} = Subject.start_link(namespace: namespace)

      assert scheduler |> Supervisor.which_children() |> length == Subject.schedules() |> length
    end

    test "schedules in the correct intervals" do
      time =
        :timer.tc(fn ->
          {:ok, _scheduler} = Subject.start_link(namespace: generate_name(Subject))

          receive do
            :every_100ms_called ->
              receive do
                :every_100ms_called ->
                  receive do
                    :every_100ms_called -> :nop
                  after
                    150 -> raise "Expected next run to have completed by now"
                  end
              after
                150 -> raise "Expected next run to have completed by now"
              end
          after
            400 -> raise "Expected all runs to have completed by now, but they didn't"
          end
        end)
        |> elem(0)

      assert_in_delta(time / 1000, 200, 50)
    end

    test "when first_in is set to 0, it performs the first run immediately" do
      namespace = generate_name(Subject)
      {:ok, _scheduler} = Subject.start_link(namespace: namespace)

      receive do
        :every_day_first_in_0 -> :nop
      after
        100 -> raise "Expected first run to have occured by now"
      end
    end
  end

  test "when first_in is set, it schedules the first run in that amount" do
    name = generate_name(Subject)
    {:ok, _scheduler} = Subject.start_link(name: name)

    time =
      :timer.tc(fn ->
        receive do
          :every_day_first_in_300ms -> :nop
        after
          400 -> raise "Expected first run to have occured by now"
        end
      end)
      |> elem(0)

    assert_in_delta(time / 1000, 300, 50)
  end

  describe "introspection" do
    test "tasks keep statistics of runs" do
      {:ok, scheduler} = Subject.start_link(name: generate_name(Subject))

      :timer.sleep(200)
      assert {_pid, %{runs: 2}} = scheduler |> find_task(%{name: :tight_schedule})
    end

    test "tasks keep statistics of failures" do
      {:ok, scheduler} = Subject.start_link(name: generate_name(Subject))

      :timer.sleep(300)
      assert {_pid, %{failures: 3}} = scheduler |> find_task(%{name: :failing})
    end

    test "tasks keep statistics of time to complete" do
      {:ok, scheduler} = Subject.start_link(name: generate_name(Subject))

      :timer.sleep(200)
      {_pid, %{last_completed_in: time}} = scheduler |> find_task(%{name: :tight_schedule})

      assert time > 0.0
    end
  end

  describe "failure handling" do
    test "when a process exceeeds :max_failures it is restarted" do
      capture_log(fn ->
        {:ok, scheduler} = Subject.start_link(name: generate_name(Subject))

        {pid, _} = scheduler |> find_task(%{name: :failing})
        assert Process.alive?(pid)

        :timer.sleep(500)

        # The old process is no longer alive
        refute Process.alive?(pid)
        {pid, _} = scheduler |> find_task(%{name: :failing})

        # A new task has been spawned
        assert Process.alive?(pid)
      end)
    end

    test "when a failing process is restarted, an error is logged" do
      log_output =
        capture_log(fn ->
          {:ok, _scheduler} = Subject.start_link(name: generate_name(Subject))
          :timer.sleep(500)
        end)

      assert log_output =~ ~r/scheduled task failed with:/
    end

    test "with unspecified :max_failures it is not restarted" do
      capture_log(fn ->
        {:ok, scheduler} = Subject.start_link(name: generate_name(Subject))

        {pid, _} = scheduler |> find_task(%{name: :failing_indefinitely})
        assert Process.alive?(pid)

        :timer.sleep(500)

        {^pid, _} = scheduler |> find_task(%{name: :failing_indefinitely})
        assert Process.alive?(pid)
      end)
    end
  end

  defp find_task(scheduler, %{name: name}) do
    scheduler
    |> Supervisor.which_children()
    |> Stream.map(fn {_, pid, _, _} -> {pid, :sys.get_state(pid)} end)
    |> Enum.find(fn {_, %{schedule: %{name: schedule_name}}} -> schedule_name == name end)
  end

  def generate_name(module) do
    :"#{module}-#{make_ref() |> inspect()}"
  end
end
