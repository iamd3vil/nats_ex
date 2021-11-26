defmodule NatsEx.ProcessGroup do
  @moduledoc false

  @type group :: term()

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  @spec start_link(term()) :: {:ok, pid()} | {:error, term()} | :ignore
  if Code.ensure_loaded?(:pg) do
    def start_link(_arg), do: :pg.start_link(__MODULE__)
  else
    def start_link(_arg), do: :ignore
  end

  @spec create(group()) :: :ok
  if Code.ensure_loaded?(:pg) do
    def create(_group), do: :ok
  else
    defdelegate create(group), to: :pg2
  end

  @spec join(group(), pid()) :: :ok
  if Code.ensure_loaded?(:pg) do
    def join(group, pid) do
      :pg.join(__MODULE__, group, pid)
    end
  else
    defdelegate join(group, pid), to: :pg2
  end

  @spec leave(group, pid()) :: :ok | {:error, {:no_such_group, group()}}
  if Code.ensure_loaded?(:pg) do
    def leave(group, pid) do
      :pg.leave(__MODULE__, group, pid)
      :ok
    end
  else
    defdelegate leave(group, pid), to: :pg2
  end

  @spec get_local_members(group()) :: [pid()] | {:error, {:no_such_group, group()}}
  if Code.ensure_loaded?(:pg) do
    def get_local_members(group) do
      :pg.get_local_members(__MODULE__, group)
    end
  else
    defdelegate get_local_members(group), to: :pg2
  end
end
