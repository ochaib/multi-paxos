# Ossama Chaib (oc3317) and Daniel Loney (dl4317)


defmodule Scout do

  def start config, leader, acceptors, ballot_number do
    Debug.starting(config)

    # Send a ⟨p2a, leader, ballot_number⟩ message to all acceptors.
    for a <- acceptors do
      send a, { :p1a, self(), ballot_number }
    end
    next config, leader, acceptors, ballot_number, MapSet.new(acceptors), MapSet.new
  end

  def next config, leader, acceptors, ballot_number, waitfor, pvalues do

    receive do
      # a = acceptor, b(2) = ballot, r = pvalue
      { :p1b, a, b2, r } ->
        # IO.puts "Scout #{inspect self()} received p1b from Acceptor #{inspect a}."

        # if received ballot response is the one sent by scout,
          # add received pvalue to the seen pvalues
          # remove the acceptor from the acceptors the scout is waiting for
          # if the quorum number of acceptors have accepted,
            # send adopted message to the leader for ballot_number with all
            # past pvalues seen
          # else notify the leader that ballot_number has been preempted
        if ballot_number == b2 do
          pvalues = MapSet.union(pvalues, r)
          waitfor = MapSet.delete(waitfor, a)

          if MapSet.size(waitfor) < (Enum.count(acceptors)/2) do
            # IO.puts "Scout #{inspect self()} has adopted #{inspect ballot_number} as "
            #         <> "its ballot number after receiving a majority of acceptors."
            send leader, { :adopted, ballot_number, pvalues }
            send config[:monitor], { :scout_finished, config[:server_num] }
          else
            next config, leader, acceptors, ballot_number, waitfor, pvalues
          end

        else
          # IO.puts "Scout #{inspect self()} has been preempted by a higher ballot number "
          #         <> " #{inspect b2}."
          send leader, { :preempted, b2 }
          send config[:monitor], { :scout_finished, config[:server_num] }
        end
    end
  end
end
