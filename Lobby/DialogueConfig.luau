return {
	NPCName = "Witch",
	StartNode = "greeting",

	Settings = {
		TypewriterSpeed = 0.02,
		SlideDuration = 0.3,
		OptionColor = Color3.fromRGB(40, 45, 60),
		OptionHoverColor = Color3.fromRGB(60, 80, 110),
		OptionTextColor = Color3.fromRGB(220, 220, 230),
		OptionWidth = 0.95,
		OptionHeight = 38,
		RemoteName = "HalloweenEvent",
	},

	Nodes = {
		greeting = {
			text = function(player)
				local isActive = player:GetAttribute("QuestActive")
				local isDone = player:GetAttribute("QuestDone")
				local pumpkins = player:GetAttribute("Pumpkins") or 0

				if isDone then
					return {
						EN = "Oh, my potion is almost ready! Bubbling, hissing... Thanks for your help, hee-hee-hee! I don't need you anymore, shoo!",
						RU = "Ох, моё зелье почти готово! Булькает, шипит... Спасибо за помощь, хи-хи-хи! Ты мне больше не нужен, убирайся!",
					}
				elseif isActive then
					if pumpkins >= 8 then
						return {
							EN = "I smell dampness and magic! You brought all 8 pumpkins! Give them to me quickly, the cauldron is waiting!",
							RU = "Чую сырость и магию! Ты принёс все 8 тыкв! Быстрее отдавай их мне, котёл ждёт!",
						}
					elseif pumpkins > 0 then
						return {
							EN = "Where are the rest? You only have " .. pumpkins .. " pumpkins! I need exactly 8! If you don't bring them all, I'll throw you into the cauldron instead! Hee-hee-hee!",
							RU = "Где остальные? У тебя всего " .. pumpkins .. " тыкв! Мне нужно ровно 8! Если не принесёшь все — брошу тебя в котёл вместо них! Хи-хи-хи!",
						}
					else
						return {
							EN = "Why are you standing there like a frozen ghoul? I told you I need 8 pumpkins! Look closer, they are hidden by magic!",
							RU = "Что стоишь как замёрзший упырь? Я же сказал — нужно 8 тыкв! Внимательнее смотри, они спрятаны магией!",
						}
					end
				else
					return {
						EN = "Hee-hee-hee... Greetings, fresh meat! Oh, I mean, traveler. My grand potion is almost complete... But alas, I am missing 8 secret pumpkins. Will you help an old witch?",
						RU = "Хи-хи-хи... Привет, свежее мясо! О, я значит — путник. Моё великое зелье почти готово... Но увы, мне не хватает 8 тайных тыкв. Поможешь старой ведьме?",
					}
				end
			end,
			options = function(player)
				local isActive = player:GetAttribute("QuestActive")
				local isDone = player:GetAttribute("QuestDone")
				local pumpkins = player:GetAttribute("Pumpkins") or 0

				if isDone then
					local hasAccessory = player:GetAttribute("AccessoryEquipped")
					local opts = {}
					if hasAccessory then
						table.insert(opts, {
							text = { EN = "Take off the witch hat", RU = "Снять ведьмину шляпу" },
							target = "__exit",
							action = "UnequipAccessory",
						})
					else
						table.insert(opts, {
							text = { EN = "Put on the witch hat", RU = "Надеть ведьмину шляпу" },
							target = "__exit",
							action = "EquipAccessory",
						})
					end
					table.insert(opts, {
						text = { EN = "Goodbye, witch!", RU = "До свидания, ведьма!" },
						target = "__exit",
					})
					return opts
				elseif isActive then
					if pumpkins >= 8 then
						return {
							{
								text = { EN = "Give ingredients", RU = "Отдать ингредиенты" },
								target = "finish_quest",
								action = "CompleteQuest",
							},
							{
								text = { EN = "I changed my mind", RU = "Я передумал" },
								target = "__exit",
							},
						}
					else
						return {
							{
								text = { EN = "I'll keep looking...", RU = "Продолжу поиск..." },
								target = "__exit",
							},
						}
					end
				else
					return {
						{
							text = { EN = "Sure, I'll find them!", RU = "Конечно, найду!" },
							target = "accept_quest",
							action = "StartQuest",
						},
						{
							text = { EN = "No way, I'm scared", RU = "Ни в коем случае, мне страшно" },
							target = "__exit",
						},
					}
				end
			end,
		},

		accept_quest = {
			text = {
				EN = "Excellent! Hee-hee-hee! I have lifted their invisibility spell. Now you can find them. And don't even think about taking a bite, or you'll turn into a toad!",
				RU = "Превосходно! Хи-хи-хи! Я сняла с них заклинание невидимости. Теперь ты сможешь их найти. И даже не думай откусить — превратишься в жабу!",
			},
			next = "__exit",
		},

		finish_quest = {
			text = {
				EN = "Perfect! Let's toss them into the cauldron... Abracadabra! Look at it sparkle! A glowing potion has risen from the cauldron — grab it, it's yours! Happy Halloween! Hee-hee-hee!",
				RU = "Прекрасно! Кидаем их в котёл... Абракадабра! Смотрите, как сверкает! Из котла поднялось сияющее зелье — хватай, оно твоё! С Хэллоуином! Хи-хи-хи!",
			},
			next = "__exit",
		},
	},
}
