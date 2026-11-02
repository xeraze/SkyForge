local InventoryConfig = {}

-- ГЛОБАЛЬНЫЕ НАСТРОЙКИ
InventoryConfig.GridColumns = 5 -- столбцов в сетке (в GUI их максимум влезает 5)
InventoryConfig.BaseCells = 45 -- ячеек без экипировки (5 x 9 строк, полный экран)
InventoryConfig.HotbarSize = 3 -- слотов хотбара снизу (в GUI слота вроде 3)
InventoryConfig.OpenKeyCode = Enum.KeyCode.Tab -- клавиша открытия инвентаря (для изменения клавиши можно глянуть здесь: https://create.roblox.com/docs/reference/engine/enums/KeyCode)

-- ЯЧЕЕК ДОБАВЛЯЕТ ПРЕДМЕТ ПРИ НАДЕВАНИИ (CellsBonus у предмета ниже)
-- Итого ячеек = BaseCells + сумма CellsBonus надетого. Пример: 45 + рюкзак 16 = 61.

-- Слоты экипировки. ParentFrameName это фрейм в GUI, куда рисовать слот
InventoryConfig.EquipmentSlots = {
	{ Id = "helmet", DisplayName = "Шлем", ParentFrameName = "ArmorFrame", AcceptedTypes = { helmet = true } },
	{ Id = "armor", DisplayName = "Броня", ParentFrameName = "ArmorFrame", AcceptedTypes = { armor = true } },
	{ Id = "backpack", DisplayName = "Рюкзак", ParentFrameName = "ArmorFrame", AcceptedTypes = { backpack = true } },
	{ Id = "nvgs", DisplayName = "Ночники", ParentFrameName = "ItemsFrame", AcceptedTypes = { nvgs = true } },
}

InventoryConfig.HotbarAcceptedTypes = { weapon = true } -- что можно класть в хотбар

-- ПРЕДМЕТЫ
-- Width/Height это размер в ячейках (горизонталь/вертикаль, меняются при повороте R)
-- Type это думаю понятно что, есть типы такие как weapon/armor/helmet/backpack/nvgs/food/medical/ammo/misc
-- CellsBonus это сколько ячеек добавляет в сетку при надевании (только для экипировки)
-- WeaponIndex это номер в WeaponConfig (какое оружие визуализируется, только для weapon)
-- Icon это просто цветная заглушка с названием
InventoryConfig.Items = {
	weapon_pistol = { Name = "Пистолет", Width = 2, Height = 1, Type = "weapon", WeaponIndex = 1, Icon = "" },
	weapon_shotgun = { Name = "Дробовик", Width = 3, Height = 1, Type = "weapon", WeaponIndex = 2, Icon = "" },
	weapon_rifle = { Name = "Винтовка", Width = 4, Height = 1, Type = "weapon", WeaponIndex = 3, Icon = "" },
	weapon_sniper = { Name = "Снайперка", Width = 5, Height = 1, Type = "weapon", WeaponIndex = 4, Icon = "" },
	knife = { Name = "Нож", Width = 1, Height = 2, Type = "weapon", Icon = "" },
	armor_vest = { Name = "Бронежилет", Width = 3, Height = 2, Type = "armor", CellsBonus = 4, Icon = "" },
	armor_helmet = { Name = "Шлем", Width = 2, Height = 2, Type = "helmet", Icon = "" },
	backpack_large = { Name = "Рюкзак", Width = 3, Height = 3, Type = "backpack", CellsBonus = 16, Icon = "" },
	nvgs = { Name = "Ночные очки", Width = 2, Height = 1, Type = "nvgs", Icon = "" },
	food_can = { Name = "Консервы", Width = 1, Height = 1, Type = "food", Icon = "" },
	food_bread = { Name = "Хлеб", Width = 1, Height = 1, Type = "food", Icon = "" },
	water_bottle = { Name = "Вода", Width = 1, Height = 1, Type = "food", Icon = "" },
	medkit = { Name = "Аптечка", Width = 2, Height = 1, Type = "medical", Icon = "" },
	ammo_box = { Name = "Патроны", Width = 2, Height = 1, Type = "ammo", Icon = "" },
	scrap = { Name = "Металлолом", Width = 1, Height = 1, Type = "misc", Icon = "" },
}

-- Стартовая выдача при спавне (id берутся из Items выше)
InventoryConfig.StartingHotbar = { "weapon_pistol", "weapon_shotgun", "weapon_rifle" }
InventoryConfig.StartingItems = {
	"weapon_sniper",
	"backpack_large",
	"armor_vest",
	"armor_helmet",
	"nvgs",
	"knife",
	"medkit",
	"ammo_box",
	"food_can",
	"food_bread",
	"water_bottle",
	"scrap",
	"scrap",
}
InventoryConfig.StartingEquipment = {} -- пример: { backpack = "backpack_large" }

InventoryConfig.TypeColors = {
	weapon = Color3.fromRGB(90, 95, 105),
	armor = Color3.fromRGB(70, 90, 120),
	helmet = Color3.fromRGB(70, 90, 120),
	backpack = Color3.fromRGB(100, 85, 60),
	nvgs = Color3.fromRGB(60, 110, 70),
	food = Color3.fromRGB(130, 100, 60),
	medical = Color3.fromRGB(150, 70, 70),
	ammo = Color3.fromRGB(120, 110, 50),
	misc = Color3.fromRGB(95, 95, 95),
}

return InventoryConfig