ranks = {'02', '03', '04', '05', '06', '07', '08', '09', '10', 'JACK', 'QUEEN', 'KING', 'ACE'}
suits = {'SPD', 'HRT', 'DIA', 'CLUB'}

function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
  return tbl
end

function getDeck()
	local tDeck = {}
	for _,rank in pairs(ranks) do
		for _,suit in pairs(suits) do
			table.insert(tDeck, suit .. "_" .. rank)
		end
	end
	return shuffle(tDeck)
end

function takeCard(tDeck)
	return table.remove(tDeck, 1)
end

function cardValue(card)
	local rank = 10
	for i=2,11 do
		if string.find(card, tostring(i)) then
			rank = i
		end
	end
	if string.find(card, 'ACE') then
		rank = 11
	end

	return rank
end

function handValue(hand)
	local tmpValue = 0
	local numAces = 0

	for i,v in pairs(hand) do
		tmpValue = tmpValue + cardValue(v)
	end

	for i,v in pairs(hand) do
		if string.find(v, 'ACE') then numAces = numAces + 1 end
	end

	repeat
		if tmpValue > 21 and numAces > 0 then
			tmpValue = tmpValue - 10
			numAces = numAces - 1
		else
			break
		end
	until numAces == 0

	return tmpValue
end

players = {}
timeTracker = {}

tableTracker = {}

getChipsCallback = nil
takeChipsCallback = nil
giveChipsCallback = nil

function FindPlayerIdx(tbl, src)

	for i = 1, #tbl do
		if tbl[i].player == src then
			return i
		end
	end

	return nil
end

function SetGetChipsCallback(cb)
	getChipsCallback = cb
end

function SetTakeChipsCallback(cb)
	takeChipsCallback = cb
end

function SetGiveChipsCallback(cb)
	giveChipsCallback = cb
end

function GiveMoney(player, money)
	if giveChipsCallback ~= nil then
		exports["np-financials"]:updateCash(player, "+", money)
		print('[RPFrogs-Blackjack] ' .. user:getName() .. ' has ' .. user:getMoney() .. '$')
	end
end

function TakeMoney(player, money)
	if giveChipsCallback ~= nil then
		exports["np-financials"]:updateCash(player, "-", money)
		print('[RPFrogs-Blackjack] ' .. user:getName() .. ' has ' .. user:getMoney() .. '$')
	end
end

function HaveAllPlayersBetted(table)
	for i,v in pairs(table) do
		if v.bet < 1 then
			return false
		end
	end
	return true
end

function ArePlayersStillIn(table)
	for i,v in pairs(table) do
		if v.player_in == true then
			return true
		end
	end
	return false
end

function PlayDealerAnim(dealer, animDict, anim)
	TriggerClientEvent("rpfrogs-blackjack:PlayDealerAnim", -1, dealer, animDict, anim)
end

function PlayDealerSpeech(dealer, speech)
	TriggerClientEvent("rpfrogs-blackjack:PlayDealerSpeech", -1, dealer, speech)
end

function SetPlayerBet(i, seat, bet, betId, double, split)
	split = split or false
	double = double or false


	local num = FindPlayerIdx(players[i], source)

	if num ~= nil then
		if double == false and split == false then
			TakeMoney(source, bet)

			players[i][num].bet = tonumber(bet)
		end

		TriggerClientEvent("rpfrogs-blackjack:PlaceBetChip", -1, i, 5-seat, bet, double, split)
	else
		DebugPrint("TABLE "..i..": PLAYER "..source.." ATTEMPTED BET BUT NO LONGER TRACKED?")
	end
end

RegisterServerEvent("rpfrogs-blackjack:SetPlayerBet")
AddEventHandler('BLACKJACK:SetPlayerBet', SetPlayerBet)

function CheckPlayerBet(i, bet)
	DebugPrint("TABLE "..i..": CHECKING "..GetPlayerName(source):upper().."'s CHIPS")

	local playerChips = 0

	if getChipsCallback ~= nil then
		playerChips = getChipsCallback(source)
	end

	local canBet = false

	if playerChips ~= nil then
		if playerChips >= bet then
			canBet = true
		end
	end

	TriggerClientEvent("rpfrogs-blackjack:BetReceived", source, canBet)
end

RegisterServerEvent("rpfrogs-blackjack:CheckPlayerBet")
AddEventHandler("rpfrogs-blackjack:CheckPlayerBet", CheckPlayerBet)

function SortPlayers(pTable)
    local temp

    for i=1,#pTable-1 do
        for j=i+1,#pTable do
            if pTable[i].seat < pTable[j].seat then
                temp = pTable[i]
                pTable[i] = pTable[j]
                pTable[j] = temp
            end
        end
    end

    return pTable
end

RegisterServerEvent("rpfrogs-blackjack:ReceivedMove")

function StartTableThread(i)
	Citizen.CreateThread(function()
		local index = 
		while true do Wait(0)
			if players[index] and #players[index] ~= 0 then
				DebugPrint("WAITING FOR ALL PLAYERS AT TABLE "..index.." TO PLACE THEIR BETS.")
				PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_place_bet_request")
				PlayDealerSpeech(index, "MINIGAME_DEALER_PLACE_CHIPS")
				repeat
					for i,v in pairs(players[index]) do
						TriggerClientEvent("rpfrogs-blackjack:SyncTimer", v.player, bettingTime - timeTracker[index])
					end
					Wait(1000)
					timeTracker[index] = timeTracker[index] + 1
				until HaveAllPlayersBetted(players[index]) or #players[index] == 0 or timeTracker[index] >= bettingTime

				if #players[index] == 0 then
					DebugPrint("BETTING ENDED AT TABLE "..index..", NO MORE PLAYERS")
				else
					for i,v in pairs(players[index]) do
						if v.bet < 1 then
							v.player_in = false
						end
					end

					if ArePlayersStillIn(players[index]) then
						DebugPrint("BETS PLACED AT TABLE "..index..", STARTING GAME")

						PlayDealerSpeech(index, "MINIGAME_DEALER_CLOSED_BETS")

						local currentPlayers = {table.unpack(players[i])}
						local deck = getDeck()
						local dealerHand = {}
						local dealerVisibleHand = {}
						TriggerClientEvent("rpfrogs-blackjack:UpdateDealerHand", -1, index, handValue(dealerVisibleHand))
						
						currentPlayers = SortPlayers(currentPlayers)

						local gameRunning = true

						Wait(1500)

						for x=1,2 do
							local card = takeCard(deck)
							table.insert(dealerHand, card)

							TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, 0, #dealerHand, card, #dealerHand == 1)

							if #dealerHand == 1 then
								PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_deal_card_self")
								DebugPrint("TABLE "..index..": DEALT DEALER [HIDDEN] ")
							else
								PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_deal_card_self_second_card")
								DebugPrint("TABLE "..index..": DEALT DEALER "..card)
								table.insert(dealerVisibleHand, card)
							end
							Wait(2000)
							TriggerClientEvent("rpfrogs-blackjack:UpdateDealerHand", -1, index, handValue(dealerVisibleHand))

							if #dealerHand > 1 then
								PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..cardValue(dealerHand[2]))
							end

							for i,v in pairs(currentPlayers) do
								if v.player_in then
									local card = takeCard(deck)
									TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.hand+1, card)
									PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_deal_card_player_0" .. 5-v.seat)
									table.insert(v.hand, card)

									Wait(2000)


									DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

									if handValue(v.hand) == 21 then
										TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "good")
										DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS BLACKJACK")
										GiveMoney(v.player, v.bet*2.5)
										v.player_in = false
										PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_BLACKJACK")
									else
										PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
									end
								end
							end
						end

						-- female_dealer_focus_player_01_idle

						if handValue(dealerHand) == 21 then
							DebugPrint("TABLE "..index..": DEALER HAS BLACKJACK")
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_check_and_turn_card")
							dealerVisibleHand = dealerHand
							Wait(2000)
							PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_BLACKJACK")
							TriggerClientEvent("rpfrogs-blackjack:DealerTurnOverCard", -1, index)
							TriggerClientEvent("rpfrogs-blackjack:UpdateDealerHand", -1, index, handValue(dealerVisibleHand))

							for i,v in pairs(currentPlayers) do
								TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
							end

							gameRunning = false
						elseif cardValue(dealerHand[2]) == 10 or cardValue(dealerHand[2]) == 11 then
							DebugPrint("TABLE "..index..": DEALER HAS A 10, CHECKING..")
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_check_card")
							Wait(2000)
						end

						if gameRunning == true then
							for i,v in pairs(currentPlayers) do
								if v.player_in then
									if tableTracker[tostring(v.player)] == nil then
										DebugPrint("TABLE "..index..": "..v.player.." WAS PUT OUT DUE TO LEAVING")
										v.player_in = false
										TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, v.seat)
									else
										PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_intro")
										Wait(1500)
										PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_ANOTHER_CARD")
										while v.player_in == true and #v.hand < 5 do
											timeTracker[index] = 0
											Wait(0)
											PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle")
											DebugPrint("TABLE "..index..": AWAITING MOVE FROM "..GetPlayerName(v.player):upper())
											TriggerClientEvent("rpfrogs-blackjack:RequestMove", v.player, moveTime - timeTracker[index])
											local receivedMove = false
											local move = "stand"
											local eventHandler = AddEventHandler("rpfrogs-blackjack:ReceivedMove", function(m)
												if source ~= v.player then return end
												move = m
												receivedMove = true
											end)

											while receivedMove == false and tableTracker[tostring(v.player)] ~= nil and timeTracker[index] < moveTime do
												for i,v in pairs(currentPlayers) do
													TriggerClientEvent("rpfrogs-blackjack:SyncTimer", v.player, moveTime - timeTracker[index])
												end
												Wait(1000)
												timeTracker[index] = timeTracker[index] + 1
											end
											RemoveEventHandler(eventHandler)

											if tableTracker[tostring(v.player)] == nil then
												DebugPrint("TABLE "..index..": "..v.player.." WAS PUT OUT DUE TO LEAVING")
												v.player_in = false
												TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, v.seat)
											else
												if move == "hit" then
													local card = takeCard(deck)
													TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.hand+1, card)
													PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_card_player_0" .. 5-v.seat)
													table.insert(v.hand, card)
													Wait(1500)
													DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

													if handValue(v.hand) == 21 then
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
														break
													elseif handValue(v.hand) > 21 then
														TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
														v.player_in = false
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
													else
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
													end
												elseif move == "double" then
													TakeMoney(v.player, v.bet)
													v.bet = v.bet*2
													local card = takeCard(deck)
													TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.hand+1, card)
													PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_card_player_0" .. 5-v.seat)
													table.insert(v.hand, card)
													Wait(1500)
													DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

													if handValue(v.hand) == 21 then
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
														break
													elseif handValue(v.hand) > 21 then
														TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
														v.player_in = false
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
													else
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
													end

													break
												elseif move == "split" then
													TakeMoney(v.player, v.bet)
													v.bet = v.bet*2
													PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_split_card_player_0" .. 5-v.seat)

													v.splitHand = {}

													local splitCard = table.remove(v.hand, 2)
													table.insert(v.splitHand, splitCard)

													Wait(500)

													TriggerClientEvent("rpfrogs-blackjack:SplitHand", -1, index, v.seat, #v.splitHand, v.hand, v.splitHand)

													Wait(1000)

													local card = takeCard(deck)
													TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.hand+1, card, false, false)
													PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_card_player_0" .. 5-v.seat)

													-- female_dealer_focus_player_01_idle_split

													table.insert(v.hand, card)
													Wait(1500)
													DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

													if handValue(v.hand) == 21 then
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_BLACKJACK")
														break
													elseif handValue(v.hand) > 21 then
														TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
													else
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
													end

													local card = takeCard(deck)
													TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.splitHand+1, card, false, true)
													PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_second_card_player_0" .. 5-v.seat)

													table.insert(v.splitHand, card)
													Wait(1500)
													DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

													if handValue(v.splitHand) == 21 then
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.splitHand))
														break
													elseif handValue(v.splitHand) > 21 then
														TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
														DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
													else
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.splitHand))
													end
													PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_ANOTHER_CARD")
													repeat Wait(0)
														timeTracker[index] = 0
														PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle")
														DebugPrint("TABLE "..index..": AWAITING MOVE FROM "..GetPlayerName(v.player):upper())
														TriggerClientEvent("rpfrogs-blackjack:RequestMove", v.player, moveTime - timeTracker[index])
														local receivedMove = false
														local move = "stand"
														local eventHandler = AddEventHandler("rpfrogs-blackjack:ReceivedMove", function(m)
															if source ~= v.player then return end
															move = m
															receivedMove = true
														end)

														while receivedMove == false and tableTracker[tostring(v.player)] ~= nil and timeTracker[index] < moveTime do
															for i,v in pairs(currentPlayers) do
																TriggerClientEvent("rpfrogs-blackjack:SyncTimer", v.player, moveTime - timeTracker[index])
															end
															Wait(1000)
															timeTracker[index] = timeTracker[index] + 1
														end

														RemoveEventHandler(eventHandler)

														if tableTracker[tostring(v.player)] == nil then
															DebugPrint("TABLE "..index..": "..v.player.." WAS PUT OUT DUE TO LEAVING")
															v.player_in = false
															TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, v.seat)
															print("breaking on 1st hand")
															break
														else
															if move == "hit" then
																local card = takeCard(deck)
																TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.hand+1, card, false, false)
																PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_card_player_0" .. 5-v.seat)
																table.insert(v.hand, card)
																Wait(1500)
																DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

																if handValue(v.hand) == 21 then
																	DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
																	PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
																	break
																elseif handValue(v.hand) > 21 then
																	TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
																	DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
																	PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
																else
																	PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.hand))
																end
															elseif move == "stand" then
																break
															end
														end
													until handValue(v.hand) >= 21 or #v.hand == 5

													if v.player_in == true then
														PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_outro")
														Wait(1500)

														PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_intro_split")
														Wait(1500)
														PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_ANOTHER_CARD")

														repeat Wait(0)
															timeTracker[index] = 0
															PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_split")
															print(""..v.player)
															DebugPrint("TABLE "..index..": AWAITING MOVE FROM "..GetPlayerName(v.player):upper())
															TriggerClientEvent("rpfrogs-blackjack:RequestMove", v.player, moveTime - timeTracker[index])
															local receivedMove = false
															local move = "stand"
															local eventHandler = AddEventHandler("rpfrogs-blackjack:ReceivedMove", function(m)
																if source ~= v.player then return end
																move = m
																receivedMove = true
															end)

															while receivedMove == false and tableTracker[tostring(v.player)] ~= nil and timeTracker[index] < moveTime do
																for i,v in pairs(currentPlayers) do
																	TriggerClientEvent("rpfrogs-blackjack:SyncTimer", v.player, moveTime - timeTracker[index])
																end
																Wait(1000)
																timeTracker[index] = timeTracker[index] + 1
															end
															RemoveEventHandler(eventHandler)

															if tableTracker[tostring(v.player)] == nil then
																DebugPrint("TABLE "..index..": "..v.player.." WAS PUT OUT DUE TO LEAVING")
																v.player_in = false
																TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, v.seat)
																break
															else
																if move == "hit" then
																	local card = takeCard(deck)
																	TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, v.seat, #v.splitHand+1, card, false, true)
																	PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_hit_second_card_player_0" .. 5-v.seat)
																	table.insert(v.splitHand, card)
																	Wait(1500)
																	DebugPrint("TABLE "..index..": DEALT "..GetPlayerName(v.player):upper().." "..card)

																	if handValue(v.splitHand) == 21 then
																		DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS 21")
																		PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.splitHand))
																		break
																	elseif handValue(v.splitHand) > 21 then
																		TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
																		DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WENT BUST")
																		PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_PLAYER_BUST")
																	else
																		PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(v.splitHand))
																	end
																elseif move == "stand" then
																	break
																end
															end
														until handValue(v.splitHand) >= 21 or #v.splitHand == 5

														if handValue(v.hand) > 21 and handValue(v.splitHand) > 21 then
															v.player_in = false
														end

														PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_outro_split")
														Wait(1500)
													end

													break

												elseif move == "stand" then
													break
												end
											end
										end

										if not v.splitHand then
											PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_dealer_focus_player_0".. 5-v.seat .."_idle_outro")
											Wait(1500)
										end
									end
								end
							end

							local j = 1

							while j <= #currentPlayers do
								local player = currentPlayers[j]

								if tableTracker[tostring(player.player)] == nil then
									DebugPrint("TABLE "..index..": "..player.player.." WAS REMOVED FROM PLAYERS LIST FOR LEAVING")
									table.remove(currentPlayers, j)
								else
									j = j + 1
								end
							end

							if ArePlayersStillIn(currentPlayers) then
								PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_turn_card")
								Wait(1000)
								TriggerClientEvent("rpfrogs-blackjack:DealerTurnOverCard", -1, index)
								dealerVisibleHand = dealerHand
								Wait(1000)
								PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(dealerHand))
								TriggerClientEvent("rpfrogs-blackjack:UpdateDealerHand", -1, index, handValue(dealerVisibleHand))
							end

							if handValue(dealerHand) < 17 and ArePlayersStillIn(currentPlayers) then
								repeat
									local card = takeCard(deck)
									table.insert(dealerHand, card)

									TriggerClientEvent("rpfrogs-blackjack:GiveCard", -1, index, 0, #dealerHand, card, #dealerHand == 1)

									PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_deal_card_self_second_card")
									DebugPrint("TABLE "..index..": DEALT DEALER "..card)
									Wait(2000)
									PlayDealerSpeech(index, "MINIGAME_BJACK_DEALER_"..handValue(dealerHand))
									TriggerClientEvent("rpfrogs-blackjack:UpdateDealerHand", -1, index, handValue(dealerVisibleHand))
								until handValue(dealerHand) >= 17
							end
						end

						if handValue(dealerHand) > 21 then
							PlayDealerSpeech(index, "MINIGAME_DEALER_BUSTS")
						end

						DebugPrint("TABLE "..index..": DEALER HAS "..handValue(dealerHand))

						for i,v in pairs(currentPlayers) do

								DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." HAS "..handValue(v.hand))

								if v.player_in == true and (handValue(v.hand) > handValue(dealerHand) or handValue(dealerHand) > 21) then -- WIN
									if v.splitHand then
										if handValue(v.splitHand) > handValue(dealerHand) or handValue(dealerHand) > 21 then -- WIN
											TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "good")
											DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WON")
											v.player_in = false
										end
									end
									TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "good")
									DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." WON")
									GiveMoney(v.player, v.bet*2)
									v.player_in = false
								end
								if v.player_in == true and handValue(v.hand) == handValue(dealerHand) then -- PUSH
									if v.splitHand then
										if handValue(v.splitHand) == handValue(dealerHand) then -- PUSH
											TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "impartial")
											DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." IS PUSH")
											v.player_in = false
										end
									end
									TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "impartial")
									DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." IS PUSH")
									GiveMoney(v.player, v.bet)
									v.player_in = false
								end
								if v.player_in == true and handValue(v.hand) < handValue(dealerHand) and handValue(dealerHand) <= 21 then -- LOSE
									if v.splitHand then
										if handValue(v.splitHand) < handValue(dealerHand) and handValue(dealerHand) <= 21 then -- LOSE
											TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
											DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." LOST")
											v.player_in = false
										end
									end
									TriggerClientEvent("rpfrogs-blackjack:GameEndReaction", v.player, "bad")
									DebugPrint("TABLE "..index..": "..GetPlayerName(v.player):upper().." LOST")
									v.player_in = false
								end
						end

						if handValue(dealerHand) >= 17 then
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@shared@dealer@", "female_dealer_reaction_impartial_var0"..math.random(1,3))
						elseif handValue(dealerHand) > 21 then
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@shared@dealer@", "female_dealer_reaction_good_var0"..math.random(1,3))
						else
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@shared@dealer@", "female_dealer_reaction_bad_var0"..math.random(1,3))
						end

						Wait(2500)

						for i,v in pairs(currentPlayers) do
							PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_retrieve_cards_player_0".. 5-v.seat)
							Wait(500)
							TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, v.seat)
							Wait(1500)

							v.bet = 0
							v.player_in = true
							v.hand = {}
							v.splitHand = nil
						end

						PlayDealerAnim(index, "anim_casino_b@amb@casino@games@blackjack@dealer", "female_retrieve_own_cards_and_remove")
						Wait(500)
						TriggerClientEvent("rpfrogs-blackjack:RetrieveCards", -1, index, 0)
						Wait(1500)

						timeTracker[index] = 0

						for i,v in pairs(currentPlayers) do
							TriggerClientEvent("rpfrogs-blackjack:RequestBets", v.player, index, timeTracker[index])
						end
					else
						for i,v in pairs(players[index]) do
							v.bet = 0
							v.player_in = true
							v.hand = {}
							v.splitHand = nil
						end

						timeTracker[index] = 0
					end
				end
			end
		end
	end)
end

Citizen.CreateThread(function()
	for i,_ in pairs(tables) do
		StartTableThread(i)
		players[i] = {}
		timeTracker[i] = 0
	end
end)

function PlayerSatDown(i, seat)
	DebugPrint(GetPlayerName(source):upper() .. " SAT DOWN AT TABLE " .. i)
	table.insert(players[i], {player = source, seat = seat, hand = {}, player_in = true, bet = 0})
	tableTracker[tostring(source)] = i
	TriggerClientEvent("rpfrogs-blackjack:RequestBets", source, i)
end

RegisterServerEvent("rpfrogs-blackjack:PlayerSatDown")
AddEventHandler('BLACKJACK:PlayerSatDown', PlayerSatDown)


function PlayerSatUp(i)
	DebugPrint(GetPlayerName(source):upper() .. " LEFT TABLE "..i)

	local num = FindPlayerIdx(players[i], source)

	if num ~= nil then
		DebugPrint(GetPlayerName(source):upper() .. " SUCCESSFULLY REMOVED FROM TABLE "..i)

		table.remove(players[i], num)
		tableTracker[tostring(source)] = nil

		PlayDealerSpeech(i, "MINIGAME_DEALER_LEAVE_NEUTRAL_GAME")
	end
end

RegisterServerEvent("rpfrogs-blackjack:PlayerSatUp")
AddEventHandler('BLACKJACK:PlayerSatUp', PlayerSatUp)

function PlayerLeft()
	local playerTbl = tableTracker[tostring(source)]

	if playerTbl ~= nil then
		DebugPrint(GetPlayerName(source):upper() .. " LEFT SERVER")

		local num = FindPlayerIdx(players[playerTbl], source)

		if num ~= nil then
			DebugPrint(GetPlayerName(source):upper() .. " REMOVED FROM TABLE FOR LEAVING")
			table.remove(players[playerTbl], num)
		end

		tableTracker[tostring(source)] = nil
	end
end

AddEventHandler("playerDropped", PlayerLeft)

function PlayerRemove(i)
	DebugPrint(GetPlayerName(source):upper() .. " LEFT TABLE "..i)

	local num = FindPlayerIdx(players[i], source)

	if num ~= nil then
		DebugPrint(GetPlayerName(source):upper() .. " SUCCESSFULLY REMOVED FROM TABLE "..i)

		local playerInfo = players[i][num]

		if playerInfo.player_in then
			if playerInfo.bet > 0 then
				GiveMoney(source, playerInfo.bet)
			end
		end

		table.remove(players[i], num)
		tableTracker[tostring(source)] = nil

		PlayDealerSpeech(i, "MINIGAME_DEALER_LEAVE_NEUTRAL_GAME")
	end
end

RegisterServerEvent("rpfrogs-blackjack:PlayerRemove")
AddEventHandler('BLACKJACK:PlayerRemove', PlayerRemove)

exports("SetGetChipsCallback", SetGetChipsCallback)
exports("SetTakeChipsCallback", SetTakeChipsCallback)
exports("SetGiveChipsCallback", SetGiveChipsCallback)