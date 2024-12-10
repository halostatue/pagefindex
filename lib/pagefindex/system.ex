defmodule Pagefindex.System do
  @moduledoc false
  alias Pagefindex.System.Real

  def cmd(command, args, opts \\ []), do: get_impl().cmd(command, args, opts)
  def find_executable(name), do: get_impl().find_executable(name)

  @spec halt(non_neg_integer() | binary() | :abort) :: no_return()
  def halt(status), do: get_impl().halt(status)

  def file_exists?(path), do: get_impl().file_exists?(path)

  defp get_impl do
    Application.get_env(:pagefindex, :system_impl, Real)
  end
end

defmodule Pagefindex.System.Real do
  @moduledoc false

  defdelegate cmd(command, args, opts), to: System
  defdelegate find_executable(name), to: System
  @spec halt(non_neg_integer() | binary() | :abort) :: no_return()
  defdelegate halt(status), to: System

  def file_exists?(path), do: File.exists?(path)
end
