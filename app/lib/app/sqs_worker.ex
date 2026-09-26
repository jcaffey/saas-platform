defmodule App.SqsWorker do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    queue_url = Keyword.fetch!(opts, :queue_url)

    Logger.info("SQS worker started")

    send(self(), :poll)

    # {:ok, %{queue_url: queue_url}}
    {:ok, %{queue_url: queue_url, active_jobs: 0, max_jobs: 5}}
  end

  @impl true
  def handle_info(:poll, %{active_jobs: active, max_jobs: max} = state)
      when active >= max do
    Process.send_after(self(), :poll, 100)
    {:noreply, state}
  end

  def handle_info(:poll, state) do
    case ExAws.SQS.receive_message(
           state.queue_url,
           wait_time_seconds: 20,
           max_number_of_messages: 1
         )
         |> ExAws.request() do
      {:ok, %{body: %{messages: messages}}} ->
        Enum.each(messages, fn message ->
          poller = self()

          Task.Supervisor.start_child(App.JobSupervisor, fn ->
            try do
              process_message(message, state.queue_url)
            after
              send(poller, :job_finished)
            end
          end)
        end)

        state = %{state | active_jobs: state.active_jobs + length(messages)}

        send(self(), :poll)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("SQS receive failed: #{inspect(reason)}")

        Process.send_after(self(), :poll, 1_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:job_finished, state) do
    send(self(), :poll)

    {:noreply, %{state | active_jobs: state.active_jobs - 1}}
  end

  defp process_message(message, queue_url) do
    Logger.info("Processing: #{message.body}")

    if String.contains?(message.body, "FAIL") do
      raise "intentional processing failure"
    end

    Process.sleep(5_000)

    ExAws.SQS.delete_message(queue_url, message.receipt_handle)
    |> ExAws.request!()

    Logger.info("Completed: #{message.body}")
  end

  # defp process_message(message) do
  #   Logger.info("Processing: #{message.body}")
  #
  #   if String.contains?(message.body, "FAIL") do
  #     raise "intentional processing failure"
  #   end
  # end

  # defp process_message(message) do
  #   Logger.info("Processing: #{message.body}")
  # end
end
