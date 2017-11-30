defmodule ClientSimulator do
  @moduledoc """
  Documentation for ClientSimulator.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ClientSimulator.hello
      :world

  """
  def main(args) do
    case length(args) do
      3 ->
        IO.puts("starting client")
        {masterClientIdStr, totalClientsStr, engineIPStr} = List.to_tuple(args)
        MasterClient.start(masterClientIdStr, String.to_integer(totalClientsStr), engineIPStr)
      _->
        IO.puts "Invalid parameters passed"
    end

    receive do
    end
  end

  def hello do
    :world
  end
end
