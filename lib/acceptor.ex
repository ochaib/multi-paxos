# Ossama Chaib (oc3317) and Daniel Loney (dl4317)


defmodule Acceptor do

  def start config do
    Debug.starting(config)

    # An acceptor state consists of two variables; a ballot number initially
    # set to ⊥, in our case we used a tuple of -1's, and an initially empty
    # set of pvalues denoting the accepted pvalues.
    initial_ballot_number = { -1, -1 }
    initial_accepted_pvalues = MapSet.new
    next config, initial_ballot_number, initial_accepted_pvalues
  end

  defp next config, ballot_number, accepted do
    # Used to return all variable names and their values
    # IO.inspect binding()

    receive do
      { :p1a, scout, b } ->
        # IO.puts "Acceptor #{inspect self()} received p1a from "
        #         <> "Leader #{inspect scout} with ballot number #{inspect b}."
        ballot_number = max ballot_number, b
        send scout, { :p1b, self(), ballot_number, accepted }
        next config, ballot_number, accepted

      { :p2a, commander, pvalue } ->
        # IO.puts "Acceptor #{inspect self()} received p2a from "
        #         <> "Leader #{inspect commander} with pvalue #{pvalue}."
        { b, _, _ } = pvalue
        accepted = if b == ballot_number do MapSet.put(accepted, pvalue) else accepted end
        send commander, { :p2b, self(), ballot_number }
        next config, ballot_number, accepted
    end

  end

end
