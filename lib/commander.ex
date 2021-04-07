# Ossama Chaib (oc3317)

defmodule Commander do

  def start config, leader, acceptors, replicas, pvalue do
    Debug.starting(config)

    # Send a ⟨p2a, leader, pvalue⟩ message to all acceptors.
    for a <- acceptors do
      # IO.puts "Commander #{inspect self()} sent p2a to all acceptor #{inspect a}."
      send a, { :p2a, self(), pvalue }
    end
    next config, leader, acceptors, replicas, pvalue, MapSet.new(acceptors)
  end

  defp next config, leader, acceptors, replicas, pvalue, waitfor do
    { ballot_number, slot_number, cmd } = pvalue

    receive do
      # If a commander receives ⟨p2b,α,b⟩ from a majority of acceptors,
      # then the commander learns that command cmd has been chosen for slot s.
      { :p2b, a, b2} ->
        # IO.puts "Commander #{inspect self()} received p2b from "
        #         <> "Acceptor #{inspect a} with ballot number #{b2}."

        # If ballot number received is the ballot number of the commander
        # remove the acceptor from the set of acceptors that are yet to send
        # a response
        if ballot_number == b2 do
          waitfor = MapSet.delete(waitfor, a)
          # If the commander has received responses from a majority
          # of acceptors, notify all replicas of command decided on
          if MapSet.size(waitfor) < (Enum.count(acceptors)/2) do
            # IO.puts "Commander #{inspect self()} has achieved a majority and "
            #         <> "decided on #{pvalue} notifying the replicas of this decision."

            for replica <- replicas do
              send replica, { :decision, slot_number, cmd }
            end
            send config[:monitor], { :commander_finished, config[:server_num] }
          else
            next config, leader, acceptors, replicas, pvalue, waitfor
          end
        else
          # Here the commander receives ⟨p2b,α',b2⟩ from some other acceptor a'
          # where b != b2, the ballot cannot make progress as there may no
          # longer exist a majority of acceptors that can accept the pvalue.
          # The command notifies its leader of the existence of another ballot
          # number and exits.
          # IO.puts "Commander #{inspect self()} received a higher ballot number #{b2} "
          #         <> "than its own #{ballot_number}, and has informed its leader that "
          #         <> "it was preempted."
          send leader, { :preempted, b2 }
          send config[:monitor], { :commander_finished, config[:server_num] }
        end
    end
  end

end
