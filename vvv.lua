--[[
    NorthDLC v7
    GUI с анимацией, настройками, горячими клавишами и экранными кнопками.
    Fly: Smooth Physics, Velocity, CFrame, AirWalk, Adaptive (Test).
    Работа режимов зависит от физики и серверных проверок конкретной игры.
]]

local NorthDLC = {}
NorthDLC.__index = NorthDLC

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

local ICONS = {
    Moon        = "rbxassetid://10734897102",
    Combat      = "rbxassetid://10734975692",
    Movement    = "rbxassetid://10734900011",
    Render      = "rbxassetid://10723346959",
    Player      = "rbxassetid://10747373176",
    Misc        = "rbxassetid://10723424838",
    Settings    = "rbxassetid://10734950309",
    Star        = "rbxassetid://7734068321",
    Search      = "rbxassetid://10734943674",
    ChevronDown = "rbxassetid://10709790948",
}

local THEMES = {
    ["Amber Gold"] = {
        Accent = Color3.fromRGB(245, 155, 60),
        AccentLight = Color3.fromRGB(255, 185, 100),
        AccentBorder = Color3.fromRGB(225, 135, 45),
    },
    ["Neon Cyan"] = {
        Accent = Color3.fromRGB(45, 195, 245),
        AccentLight = Color3.fromRGB(115, 225, 255),
        AccentBorder = Color3.fromRGB(35, 170, 225),
    },
    ["Acid Lime"] = {
        Accent = Color3.fromRGB(130, 225, 50),
        AccentLight = Color3.fromRGB(170, 250, 90),
        AccentBorder = Color3.fromRGB(110, 205, 40),
    },
    ["Royal Purple"] = {
        Accent = Color3.fromRGB(175, 95, 250),
        AccentLight = Color3.fromRGB(210, 145, 255),
        AccentBorder = Color3.fromRGB(150, 75, 225),
    },
    ["Crimson Red"] = {
        Accent = Color3.fromRGB(245, 60, 60),
        AccentLight = Color3.fromRGB(255, 110, 110),
        AccentBorder = Color3.fromRGB(220, 45, 45),
    },
}

local currentThemeName = "Amber Gold"
local THEME = {
    Background       = Color3.fromRGB(20, 20, 22),
    LeftPanel        = Color3.fromRGB(16, 16, 18),
    PanelRight       = Color3.fromRGB(18, 18, 20),
    CardIdle         = Color3.fromRGB(28, 28, 31),
    CardActive       = Color3.fromRGB(38, 34, 32),
    SearchBg         = Color3.fromRGB(24, 24, 26),
    
    Accent           = THEMES[currentThemeName].Accent,
    AccentLight      = THEMES[currentThemeName].AccentLight,
    AccentBorder     = THEMES[currentThemeName].AccentBorder,
    
    TextPrimary      = Color3.fromRGB(245, 245, 245),
    TextSecondary    = Color3.fromRGB(180, 180, 185),
    TextMuted        = Color3.fromRGB(115, 115, 120),
    StrokeSubtle     = Color3.fromRGB(44, 44, 48),
}

local function getSafeGuiParent()
    local success, parent = pcall(function()
        if gethui then return gethui() end
        return CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function tween(object, properties, duration, style, direction)
    style = style or Enum.EasingStyle.Cubic
    direction = direction or Enum.EasingDirection.Out
    duration = duration or 0.2
    local tw = TweenService:Create(object, TweenInfo.new(duration, style, direction), properties)
    tw:Play()
    return tw
end

local function makeDraggable(self, topbar, object)
    local dragging = false
    local dragInput, dragStart, startPos

    self:Connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if self.MenuAnimating and object == self.MainFrame then return end
            dragging = true
            dragStart = input.Position
            startPos = object.Position


        end
    end)

    self:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    self:Connect(topbar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    self:Connect(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function NorthDLC:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function NorthDLC:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.CancelMenuAnimation then self.CancelMenuAnimation() end
    for _, module in ipairs(self.Modules) do
        if module.State then
            module.State = false
            local ok, err = pcall(module.Callback, false)
            if not ok then warn("[NorthDLC] Cleanup " .. module.Name .. ": " .. tostring(err)) end
        end
    end
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections)
    if self.OnDestroy then self.OnDestroy() end
    if self.ScreenGui then self.ScreenGui:Destroy() end
end

function NorthDLC.CreateWindow(config)
    config = config or {}
    local Title = config.Title or "NorthDLC"

    local self = setmetatable({}, NorthDLC)
    self.Connections = {}
    self.Destroyed = false
    self.Categories = {}
    self.CurrentCategory = nil
    self.SelectedModule = nil
    self.Modules = {}
    self.Dropdowns = {}
    self.MobileButtons = {}

    local existing = getSafeGuiParent():FindFirstChild("NorthDLC_Gui")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NorthDLC_Gui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = getSafeGuiParent()
    self.ScreenGui = ScreenGui
    self:Connect(ScreenGui.Destroying, function() self:Destroy() end)

    -- Плавающая кнопка
    local ToggleButton = Instance.new("ImageButton")
    ToggleButton.Name = "FloatingToggle"
    ToggleButton.Size = UDim2.new(0, 44, 0, 44)
    ToggleButton.Position = UDim2.new(0, 16, 0.5, -22)
    ToggleButton.BackgroundColor3 = THEME.Background
    ToggleButton.AutoButtonColor = false
    ToggleButton.Parent = ScreenGui

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(1, 0)
    ToggleCorner.Parent = ToggleButton

    local ToggleStroke = Instance.new("UIStroke")
    ToggleStroke.Color = THEME.Accent
    ToggleStroke.Thickness = 1.5
    ToggleStroke.Parent = ToggleButton
    self.ToggleStroke = ToggleStroke

    local ToggleIcon = Instance.new("ImageLabel")
    ToggleIcon.Size = UDim2.new(0, 22, 0, 22)
    ToggleIcon.Position = UDim2.new(0.5, -11, 0.5, -11)
    ToggleIcon.BackgroundTransparency = 1
    ToggleIcon.Image = ICONS.Moon
    ToggleIcon.ImageColor3 = THEME.AccentLight
    ToggleIcon.Parent = ToggleButton
    self.ToggleIcon = ToggleIcon

    makeDraggable(self, ToggleButton, ToggleButton)

    -- Главное окно
    local MainFrame = Instance.new("CanvasGroup")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 880, 0, 470)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.fromScale(0.5, 0.5)
    MainFrame.BackgroundColor3 = THEME.Background
    MainFrame.Parent = ScreenGui
    self.MainFrame = MainFrame

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = THEME.AccentBorder
    MainStroke.Thickness = 1.8
    MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MainStroke.Parent = MainFrame
    self.MainStroke = MainStroke

    local MenuScale = Instance.new("UIScale")
    MenuScale.Parent = MainFrame
    local isOpen = false
    local openPosition = MainFrame.Position
    local animationTweens = {}
    local animationCompleted

    local function cancelMenuAnimation()
        if animationCompleted then animationCompleted:Disconnect() animationCompleted = nil end
        for _, animation in ipairs(animationTweens) do animation:Cancel() end
        table.clear(animationTweens)
        self.MenuAnimating = false
    end
    self.CancelMenuAnimation = cancelMenuAnimation

    local function setMenuVisible(state)
        if self.Destroyed or state == isOpen then return end
        -- Capture only the fully open position, so rapid toggles cannot cause drift.
        if isOpen and not self.MenuAnimating then openPosition = MainFrame.Position end
        cancelMenuAnimation()
        isOpen = state
        self.MenuAnimating = true
        MainFrame.Visible = true
        local duration = state and 0.28 or 0.20
        local direction = state and Enum.EasingDirection.Out or Enum.EasingDirection.In
        animationTweens = {
            tween(MainFrame, {
                Position = state and openPosition or openPosition + UDim2.fromOffset(0, 16),
                GroupTransparency = state and 0 or 1,
            }, duration, Enum.EasingStyle.Quart, direction),
            tween(MenuScale, {Scale = state and 1 or 0.96}, duration, Enum.EasingStyle.Quart, direction),
        }
        animationCompleted = animationTweens[1].Completed:Connect(function(playbackState)
            if playbackState ~= Enum.PlaybackState.Completed then return end
            if animationCompleted then animationCompleted:Disconnect() animationCompleted = nil end
            self.MenuAnimating = false
            MainFrame.Visible = isOpen
        end)
    end
    self.SetMenuVisible = function(_, state) setMenuVisible(state) end
    MainFrame.GroupTransparency = 1
    MainFrame.Position = openPosition + UDim2.fromOffset(0, 16)
    MenuScale.Scale = 0.96
    setMenuVisible(true)

    self:Connect(ToggleButton.MouseButton1Click, function()
        setMenuVisible(not isOpen)
    end)

    self:Connect(UserInputService.InputBegan, function(input, gpe)
        if not gpe and not self.BindingModule and not UserInputService:GetFocusedTextBox() and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert) then
            setMenuVisible(not isOpen)
        end
    end)

    -- Левая панель
    local LeftPanel = Instance.new("Frame")
    LeftPanel.Name = "LeftPanel"
    LeftPanel.Size = UDim2.new(0, 205, 1, 0)
    LeftPanel.BackgroundColor3 = THEME.LeftPanel
    LeftPanel.BorderSizePixel = 0
    LeftPanel.Parent = MainFrame

    local LeftCorner = Instance.new("UICorner")
    LeftCorner.CornerRadius = UDim.new(0, 14)
    LeftCorner.Parent = LeftPanel

    makeDraggable(self, LeftPanel, MainFrame)

    local LogoContainer = Instance.new("Frame")
    LogoContainer.Name = "LogoContainer"
    LogoContainer.Size = UDim2.new(1, 0, 0, 82)
    LogoContainer.BackgroundTransparency = 1
    LogoContainer.Parent = LeftPanel

    local MoonIcon = Instance.new("ImageLabel")
    MoonIcon.Size = UDim2.new(0, 32, 0, 32)
    MoonIcon.Position = UDim2.new(0.5, -16, 0, 14)
    MoonIcon.BackgroundTransparency = 1
    MoonIcon.Image = ICONS.Moon
    MoonIcon.ImageColor3 = THEME.Accent
    MoonIcon.Parent = LogoContainer
    self.MoonIcon = MoonIcon

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, 0, 0, 20)
    TitleLabel.Position = UDim2.new(0, 0, 0, 50)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Title
    TitleLabel.TextColor3 = THEME.TextPrimary
    TitleLabel.Font = Enum.Font.GothamMedium
    TitleLabel.TextSize = 15
    TitleLabel.Parent = LogoContainer

    local SearchBoxFrame = Instance.new("Frame")
    SearchBoxFrame.Size = UDim2.new(1, -28, 0, 32)
    SearchBoxFrame.Position = UDim2.new(0, 14, 0, 92)
    SearchBoxFrame.BackgroundColor3 = THEME.SearchBg
    SearchBoxFrame.Parent = LeftPanel

    local SearchBoxCorner = Instance.new("UICorner")
    SearchBoxCorner.CornerRadius = UDim.new(0, 7)
    SearchBoxCorner.Parent = SearchBoxFrame

    local SearchBoxStroke = Instance.new("UIStroke")
    SearchBoxStroke.Color = THEME.StrokeSubtle
    SearchBoxStroke.Thickness = 1
    SearchBoxStroke.Parent = SearchBoxFrame

    local SearchIconImg = Instance.new("ImageLabel")
    SearchIconImg.Size = UDim2.new(0, 14, 0, 14)
    SearchIconImg.Position = UDim2.new(0, 10, 0.5, -7)
    SearchIconImg.BackgroundTransparency = 1
    SearchIconImg.Image = ICONS.Search
    SearchIconImg.ImageColor3 = THEME.TextMuted
    SearchIconImg.Parent = SearchBoxFrame

    local SearchInput = Instance.new("TextBox")
    self.SearchInput = SearchInput
    SearchInput.Name = "SearchInput"
    SearchInput.Size = UDim2.new(1, -34, 1, 0)
    SearchInput.Position = UDim2.new(0, 30, 0, 0)
    SearchInput.BackgroundTransparency = 1
    SearchInput.PlaceholderText = "Поиск..."
    SearchInput.PlaceholderColor3 = THEME.TextMuted
    SearchInput.Text = ""
    SearchInput.TextColor3 = THEME.TextPrimary
    SearchInput.Font = Enum.Font.Gotham
    SearchInput.TextSize = 12
    SearchInput.TextXAlignment = Enum.TextXAlignment.Left
    SearchInput.ClearTextOnFocus = false
    SearchInput.Parent = SearchBoxFrame

    local SectionLabel = Instance.new("TextLabel")
    SectionLabel.Size = UDim2.new(1, -30, 0, 18)
    SectionLabel.Position = UDim2.new(0, 18, 0, 134)
    SectionLabel.BackgroundTransparency = 1
    SectionLabel.Text = "Основное"
    SectionLabel.TextColor3 = THEME.TextMuted
    SectionLabel.Font = Enum.Font.GothamMedium
    SectionLabel.TextSize = 10
    SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
    SectionLabel.Parent = LeftPanel

    local CategoryScroll = Instance.new("ScrollingFrame")
    CategoryScroll.Name = "CategoryScroll"
    CategoryScroll.Size = UDim2.new(1, -16, 1, -162)
    CategoryScroll.Position = UDim2.new(0, 8, 0, 156)
    CategoryScroll.BackgroundTransparency = 1
    CategoryScroll.BorderSizePixel = 0
    CategoryScroll.ScrollBarThickness = 0
    CategoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    CategoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    CategoryScroll.Parent = LeftPanel
    self.CategoryScroll = CategoryScroll

    local CategoryLayout = Instance.new("UIListLayout")
    CategoryLayout.Padding = UDim.new(0, 4)
    CategoryLayout.Parent = CategoryScroll

    -- Центральная панель
    local CenterPanel = Instance.new("Frame")
    CenterPanel.Name = "CenterPanel"
    CenterPanel.Size = UDim2.new(0, 310, 1, 0)
    CenterPanel.Position = UDim2.new(0, 215, 0, 0)
    CenterPanel.BackgroundTransparency = 1
    CenterPanel.Parent = MainFrame

    local CatHeaderFrame = Instance.new("Frame")
    CatHeaderFrame.Name = "CatHeaderFrame"
    CatHeaderFrame.Size = UDim2.new(1, 0, 0, 52)
    CatHeaderFrame.Position = UDim2.new(0, 14, 0, 14)
    CatHeaderFrame.BackgroundTransparency = 1
    CatHeaderFrame.Parent = CenterPanel

    local CatHeaderTitle = Instance.new("TextLabel")
    CatHeaderTitle.Size = UDim2.new(1, 0, 0, 18)
    CatHeaderTitle.BackgroundTransparency = 1
    CatHeaderTitle.RichText = true
    CatHeaderTitle.Text = "Категория: Movement"
    CatHeaderTitle.TextColor3 = THEME.TextPrimary
    CatHeaderTitle.Font = Enum.Font.GothamMedium
    CatHeaderTitle.TextSize = 13
    CatHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
    CatHeaderTitle.Parent = CatHeaderFrame
    self.CatHeaderTitle = CatHeaderTitle

    local CatHeaderDesc = Instance.new("TextLabel")
    CatHeaderDesc.Size = UDim2.new(1, 0, 0, 15)
    CatHeaderDesc.Position = UDim2.new(0, 0, 0, 20)
    CatHeaderDesc.BackgroundTransparency = 1
    CatHeaderDesc.Text = "перемещение и скорость"
    CatHeaderDesc.TextColor3 = THEME.TextMuted
    CatHeaderDesc.Font = Enum.Font.Gotham
    CatHeaderDesc.TextSize = 10
    CatHeaderDesc.TextXAlignment = Enum.TextXAlignment.Left
    CatHeaderDesc.Parent = CatHeaderFrame
    self.CatHeaderDesc = CatHeaderDesc

    local ModuleScroll = Instance.new("ScrollingFrame")
    ModuleScroll.Name = "ModuleScroll"
    ModuleScroll.Size = UDim2.new(1, -16, 1, -80)
    ModuleScroll.Position = UDim2.new(0, 14, 0, 70)
    ModuleScroll.BackgroundTransparency = 1
    ModuleScroll.BorderSizePixel = 0
    ModuleScroll.ScrollBarThickness = 2
    ModuleScroll.ScrollBarImageColor3 = THEME.StrokeSubtle
    ModuleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ModuleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ModuleScroll.Parent = CenterPanel
    self.ModuleScroll = ModuleScroll

    local ModuleLayout = Instance.new("UIListLayout")
    ModuleLayout.Padding = UDim.new(0, 6)
    ModuleLayout.Parent = ModuleScroll

    -- Правая панель
    local RightPanel = Instance.new("Frame")
    RightPanel.Name = "RightPanel"
    RightPanel.Size = UDim2.new(1, -545, 1, -24)
    RightPanel.Position = UDim2.new(0, 532, 0, 12)
    RightPanel.BackgroundColor3 = THEME.PanelRight
    RightPanel.Parent = MainFrame

    local RightCorner = Instance.new("UICorner")
    RightCorner.CornerRadius = UDim.new(0, 12)
    RightCorner.Parent = RightPanel

    local RightStroke = Instance.new("UIStroke")
    RightStroke.Color = THEME.StrokeSubtle
    RightStroke.Thickness = 1
    RightStroke.Parent = RightPanel

    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Size = UDim2.new(1, -28, 0, 24)
    SettingsTitle.Position = UDim2.new(0, 16, 0, 12)
    SettingsTitle.BackgroundTransparency = 1
    SettingsTitle.RichText = true
    SettingsTitle.Text = "Настройки: <font color=\"rgb(115,115,120)\">Пусто :(</font>"
    SettingsTitle.TextColor3 = THEME.TextPrimary
    SettingsTitle.Font = Enum.Font.GothamMedium
    SettingsTitle.TextSize = 13
    SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SettingsTitle.Parent = RightPanel
    self.SettingsTitle = SettingsTitle

    local EmptyHint = Instance.new("TextLabel")
    EmptyHint.Name = "EmptyHint"
    EmptyHint.Size = UDim2.new(1, -40, 0, 60)
    EmptyHint.Position = UDim2.new(0, 20, 0.45, 0)
    EmptyHint.BackgroundTransparency = 1
    EmptyHint.Text = "Нажмите по шестерёнке модуля\nдля открытия настроек"
    EmptyHint.TextColor3 = THEME.TextMuted
    EmptyHint.Font = Enum.Font.Gotham
    EmptyHint.TextSize = 11
    EmptyHint.Parent = RightPanel
    self.EmptyHint = EmptyHint

    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Name = "SettingsScroll"
    SettingsScroll.Size = UDim2.new(1, -20, 1, -52)
    SettingsScroll.Position = UDim2.new(0, 10, 0, 42)
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.BorderSizePixel = 0
    SettingsScroll.ScrollBarThickness = 2
    SettingsScroll.ScrollBarImageColor3 = THEME.StrokeSubtle
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SettingsScroll.Visible = false
    SettingsScroll.Parent = RightPanel
    self.SettingsScroll = SettingsScroll

    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Padding = UDim.new(0, 8)
    SettingsLayout.Parent = SettingsScroll

    self:Connect(SearchInput:GetPropertyChangedSignal("Text"), function()
        local query = string.lower(SearchInput.Text)
        for _, mod in ipairs(self.Modules) do
            if mod.Card then
                if query == "" then
                    mod.Card.Visible = (mod.Category == self.CurrentCategory)
                else
                    local match = string.find(string.lower(mod.Name), query, 1, true) or string.find(string.lower(mod.Description), query, 1, true)
                    mod.Card.Visible = (match ~= nil)
                end
            end
        end
    end)

    return self
end

function NorthDLC:SetTheme(themeName)
    local preset = THEMES[themeName]
    if not preset then return end
    currentThemeName = themeName

    THEME.Accent = preset.Accent
    THEME.AccentLight = preset.AccentLight
    THEME.AccentBorder = preset.AccentBorder

    tween(self.MainStroke, {Color = THEME.AccentBorder}, 0.2)
    tween(self.MoonIcon, {ImageColor3 = THEME.Accent}, 0.2)
    if self.ToggleStroke then tween(self.ToggleStroke, {Color = THEME.Accent}, 0.2) end
    if self.ToggleIcon then tween(self.ToggleIcon, {ImageColor3 = THEME.AccentLight}, 0.2) end

    if self.CurrentCategory and self.CurrentCategory.Icon then
        tween(self.CurrentCategory.Icon, {ImageColor3 = THEME.Accent}, 0.2)
        self.CatHeaderTitle.Text = string.format("Категория: <font color=\"rgb(%d,%d,%d)\">%s</font>",
            THEME.Accent.R * 255, THEME.Accent.G * 255, THEME.Accent.B * 255, self.CurrentCategory.Name)
    end

    if self.SelectedModule then
        self.SettingsTitle.Text = string.format("Настройки: <font color=\"rgb(%d,%d,%d)\">%s</font>",
            THEME.Accent.R * 255, THEME.Accent.G * 255, THEME.Accent.B * 255, self.SelectedModule.Name)
    end

    for _, mod in ipairs(self.Modules) do
        if mod.State and mod.OutlineFrame then
            tween(mod.OutlineFrame, {BackgroundColor3 = THEME.Accent}, 0.2)
            if mod.TitleLabel then
                tween(mod.TitleLabel, {TextColor3 = THEME.AccentLight}, 0.2)
            end
        end
        if mod.MobileButton and mod.State then
            mod.MobileButton.UpdateVisual(true)
        end
    end

    for _, drop in ipairs(self.Dropdowns) do
        if drop.UpdateColors then drop.UpdateColors() end
    end
end

function NorthDLC:AddCategory(config)
    config = config or {}
    local Name = config.Name or "Category"
    local IconType = config.IconType or "Combat"
    local Description = config.Description or "описание раздела"

    local iconAsset = ICONS[IconType] or ICONS.Combat
    local categoryData = {Name = Name, Description = Description}

    local CatBtn = Instance.new("TextButton")
    CatBtn.Name = "CatBtn_" .. Name
    CatBtn.Size = UDim2.new(1, 0, 0, 36)
    CatBtn.BackgroundColor3 = THEME.CardIdle
    CatBtn.BackgroundTransparency = 1
    CatBtn.AutoButtonColor = false
    CatBtn.Text = ""
    CatBtn.Parent = self.CategoryScroll

    local CatCorner = Instance.new("UICorner")
    CatCorner.CornerRadius = UDim.new(0, 8)
    CatCorner.Parent = CatBtn

    local CatIcon = Instance.new("ImageLabel")
    CatIcon.Size = UDim2.new(0, 16, 0, 16)
    CatIcon.Position = UDim2.new(0, 12, 0.5, -8)
    CatIcon.BackgroundTransparency = 1
    CatIcon.Image = iconAsset
    CatIcon.ImageColor3 = THEME.TextMuted
    CatIcon.Parent = CatBtn

    local CatText = Instance.new("TextLabel")
    CatText.Size = UDim2.new(1, -38, 1, 0)
    CatText.Position = UDim2.new(0, 36, 0, 0)
    CatText.BackgroundTransparency = 1
    CatText.Text = Name
    CatText.TextColor3 = THEME.TextSecondary
    CatText.Font = Enum.Font.GothamMedium
    CatText.TextSize = 12
    CatText.TextXAlignment = Enum.TextXAlignment.Left
    CatText.Parent = CatBtn

    categoryData.Button = CatBtn
    categoryData.Icon = CatIcon
    categoryData.Text = CatText

    local function selectCategory()
        self.CurrentCategory = categoryData
        self.CatHeaderTitle.Text = string.format("Категория: <font color=\"rgb(%d,%d,%d)\">%s</font>",
            THEME.Accent.R * 255, THEME.Accent.G * 255, THEME.Accent.B * 255, Name)
        self.CatHeaderDesc.Text = Description

        for _, cat in ipairs(self.Categories) do
            if cat == categoryData then
                tween(cat.Button, {BackgroundTransparency = 0, BackgroundColor3 = THEME.CardActive}, 0.15)
                tween(cat.Icon, {ImageColor3 = THEME.Accent}, 0.15)
                tween(cat.Text, {TextColor3 = THEME.TextPrimary}, 0.15)
            else
                tween(cat.Button, {BackgroundTransparency = 1}, 0.15)
                tween(cat.Icon, {ImageColor3 = THEME.TextMuted}, 0.15)
                tween(cat.Text, {TextColor3 = THEME.TextSecondary}, 0.15)
            end
        end

        for _, mod in ipairs(self.Modules) do
            if mod.Card then
                local query = string.lower(self.SearchInput.Text)
                mod.Card.Visible = query == "" and mod.Category == categoryData or query ~= "" and (
                    string.find(string.lower(mod.Name), query, 1, true) ~= nil or
                    string.find(string.lower(mod.Description), query, 1, true) ~= nil
                )
            end
        end
    end

    self:Connect(CatBtn.MouseButton1Click, selectCategory)
    table.insert(self.Categories, categoryData)

    if #self.Categories == 1 then
        selectCategory()
    end

    return categoryData
end

function NorthDLC:AddModule(category, config)
    config = config or {}
    local Name = config.Name or "Module"
    local Description = config.Description or "Описание модуля"
    local DefaultState = config.Default or false
    local Callback = config.Callback or function() end

    local moduleData = {
        Name = Name,
        Description = Description,
        Category = category,
        State = DefaultState,
        Callback = Callback,
        Settings = {},
        Card = nil,
        Keybind = nil,
        MobileButton = nil,
    }

    local OutlineFrame = Instance.new("Frame")
    OutlineFrame.Name = "ModOutline_" .. Name
    OutlineFrame.Size = UDim2.new(1, 0, 0, 52)
    OutlineFrame.BackgroundColor3 = DefaultState and THEME.Accent or THEME.StrokeSubtle
    OutlineFrame.Visible = (self.CurrentCategory == category)
    OutlineFrame.Parent = self.ModuleScroll

    local OutlineCorner = Instance.new("UICorner")
    OutlineCorner.CornerRadius = UDim.new(0, 8)
    OutlineCorner.Parent = OutlineFrame
    moduleData.OutlineFrame = OutlineFrame

    local CardInner = Instance.new("Frame")
    CardInner.Name = "CardInner"
    CardInner.Size = UDim2.new(1, -2, 1, -2)
    CardInner.Position = UDim2.new(0, 1, 0, 1)
    CardInner.BackgroundColor3 = DefaultState and THEME.CardActive or THEME.CardIdle
    CardInner.Parent = OutlineFrame

    local CardInnerCorner = Instance.new("UICorner")
    CardInnerCorner.CornerRadius = UDim.new(0, 7)
    CardInnerCorner.Parent = CardInner

    local TextContainer = Instance.new("Frame")
    TextContainer.Size = UDim2.new(1, -74, 1, 0)
    TextContainer.BackgroundTransparency = 1
    TextContainer.ClipsDescendants = true
    TextContainer.Parent = CardInner

    local ClickArea = Instance.new("TextButton")
    ClickArea.Size = UDim2.new(1, 0, 1, 0)
    ClickArea.BackgroundTransparency = 1
    ClickArea.Text = ""
    ClickArea.Parent = TextContainer

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -12, 0, 16)
    TitleLabel.Position = UDim2.new(0, 12, 0, 8)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Name
    TitleLabel.TextColor3 = DefaultState and THEME.AccentLight or THEME.TextPrimary
    TitleLabel.Font = Enum.Font.GothamMedium
    TitleLabel.TextSize = 12
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.Parent = ClickArea
    moduleData.TitleLabel = TitleLabel

    local DescLabel = Instance.new("TextLabel")
    DescLabel.Size = UDim2.new(1, -12, 0, 14)
    DescLabel.Position = UDim2.new(0, 12, 0, 26)
    DescLabel.BackgroundTransparency = 1
    DescLabel.Text = Description
    DescLabel.TextColor3 = THEME.TextMuted
    DescLabel.Font = Enum.Font.Gotham
    DescLabel.TextSize = 10
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    DescLabel.TextTruncate = Enum.TextTruncate.AtEnd
    DescLabel.Parent = ClickArea

    local StarBtn = Instance.new("ImageButton")
    StarBtn.Size = UDim2.new(0, 15, 0, 15)
    StarBtn.Position = UDim2.new(1, -48, 0.5, -7)
    StarBtn.BackgroundTransparency = 1
    StarBtn.Image = ICONS.Star
    StarBtn.ImageColor3 = THEME.TextMuted
    StarBtn.Parent = CardInner

    local isFavorite = false
    self:Connect(StarBtn.MouseButton1Click, function()
        isFavorite = not isFavorite
        tween(StarBtn, {ImageColor3 = isFavorite and THEME.Accent or THEME.TextMuted}, 0.15)
    end)

    local GearBtn = Instance.new("ImageButton")
    GearBtn.Size = UDim2.new(0, 15, 0, 15)
    GearBtn.Position = UDim2.new(1, -25, 0.5, -7)
    GearBtn.BackgroundTransparency = 1
    GearBtn.Image = ICONS.Settings
    GearBtn.ImageColor3 = THEME.TextMuted
    GearBtn.Parent = CardInner

    local function setModuleState(newState)
        if self.Destroyed or moduleData.State == newState then return end
        moduleData.State = newState
        if moduleData.State then
            tween(OutlineFrame, {BackgroundColor3 = THEME.Accent}, 0.15)
            tween(CardInner, {BackgroundColor3 = THEME.CardActive}, 0.15)
            tween(TitleLabel, {TextColor3 = THEME.AccentLight}, 0.15)
        else
            tween(OutlineFrame, {BackgroundColor3 = THEME.StrokeSubtle}, 0.15)
            tween(CardInner, {BackgroundColor3 = THEME.CardIdle}, 0.15)
            tween(TitleLabel, {TextColor3 = THEME.TextPrimary}, 0.15)
        end
        if moduleData.MobileButton then
            moduleData.MobileButton.UpdateVisual(moduleData.State)
        end
        local ok, err = pcall(moduleData.Callback, moduleData.State)
        if not ok then warn("[NorthDLC] " .. moduleData.Name .. ": " .. tostring(err)) end
    end

    moduleData.SetState = setModuleState

    moduleData.Toggle = function()
        setModuleState(not moduleData.State)
    end

    self:Connect(ClickArea.MouseButton1Click, function()
        setModuleState(not moduleData.State)
    end)

    self:Connect(GearBtn.MouseButton1Click, function()
        self:OpenModuleSettings(moduleData)
    end)

    self:AddKeybindControl(moduleData)
    self:AddMobileHudControl(moduleData)

    moduleData.Card = OutlineFrame
    table.insert(self.Modules, moduleData)
    return moduleData
end

function NorthDLC:OpenModuleSettings(moduleData)
    self.SelectedModule = moduleData
    self.SettingsTitle.Text = string.format("Настройки: <font color=\"rgb(%d,%d,%d)\">%s</font>",
        THEME.Accent.R * 255, THEME.Accent.G * 255, THEME.Accent.B * 255, moduleData.Name)

    for _, child in ipairs(self.SettingsScroll:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
            child.Visible = false
        end
    end

    self.EmptyHint.Visible = (#moduleData.Settings == 0)
    self.SettingsScroll.Visible = (#moduleData.Settings > 0)

    for _, settingGui in ipairs(moduleData.Settings) do
        settingGui.Visible = true
    end
end

function NorthDLC:AddKeybindControl(moduleData)
    local BindFrame = Instance.new("Frame")
    BindFrame.Size = UDim2.new(1, 0, 0, 36)
    BindFrame.BackgroundColor3 = THEME.CardIdle
    BindFrame.Visible = false
    BindFrame.Parent = self.SettingsScroll

    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 7)
    BCorner.Parent = BindFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0.6, 0, 1, 0)
    NameLabel.Position = UDim2.new(0, 12, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = "Горячая клавиша (Bind)"
    NameLabel.TextColor3 = THEME.TextSecondary
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextSize = 11
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = BindFrame

    local BindBtn = Instance.new("TextButton")
    BindBtn.Size = UDim2.new(0, 68, 0, 22)
    BindBtn.Position = UDim2.new(1, -78, 0.5, -11)
    BindBtn.BackgroundColor3 = THEME.SearchBg
    BindBtn.Text = "NONE"
    BindBtn.TextColor3 = THEME.Accent
    BindBtn.Font = Enum.Font.GothamMedium
    BindBtn.TextSize = 10
    BindBtn.Parent = BindFrame

    local BBCorner = Instance.new("UICorner")
    BBCorner.CornerRadius = UDim.new(0, 5)
    BBCorner.Parent = BindBtn

    local isListening = false
    self:Connect(BindBtn.MouseButton1Click, function()
        if isListening or self.BindingModule then return end
        self.BindingModule = moduleData
        isListening = true
        BindBtn.Text = "..."
        BindBtn.TextColor3 = THEME.AccentLight

        local conn
        conn = self:Connect(UserInputService.InputBegan, function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                conn:Disconnect()
                isListening = false
                task.defer(function() self.BindingModule = nil end)
                if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
                    moduleData.Keybind = nil
                    BindBtn.Text = "NONE"
                    BindBtn.TextColor3 = THEME.TextMuted
                else
                    moduleData.Keybind = input.KeyCode
                    BindBtn.Text = input.KeyCode.Name
                    BindBtn.TextColor3 = THEME.Accent
                end
            end
        end)
    end)

    self:Connect(UserInputService.InputBegan, function(input, gpe)
        if not gpe and not isListening and not self.BindingModule and not UserInputService:GetFocusedTextBox() and moduleData.Keybind and input.KeyCode == moduleData.Keybind then
            moduleData.Toggle()
        end
    end)

    table.insert(moduleData.Settings, BindFrame)
end

function NorthDLC:AddMobileHudControl(moduleData)
    local HudFrame = Instance.new("Frame")
    HudFrame.Size = UDim2.new(1, 0, 0, 36)
    HudFrame.BackgroundColor3 = THEME.CardIdle
    HudFrame.Visible = false
    HudFrame.Parent = self.SettingsScroll

    local HCorner = Instance.new("UICorner")
    HCorner.CornerRadius = UDim.new(0, 7)
    HCorner.Parent = HudFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -80, 1, 0)
    NameLabel.Position = UDim2.new(0, 12, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = "Экранная кнопка"
    NameLabel.TextColor3 = THEME.TextSecondary
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextSize = 11
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = HudFrame

    local AddBtn = Instance.new("TextButton")
    AddBtn.Size = UDim2.new(0, 64, 0, 22)
    AddBtn.Position = UDim2.new(1, -74, 0.5, -11)
    AddBtn.BackgroundColor3 = THEME.SearchBg
    AddBtn.Text = "+ Кнопка"
    AddBtn.TextColor3 = THEME.TextSecondary
    AddBtn.Font = Enum.Font.GothamMedium
    AddBtn.TextSize = 10
    AddBtn.Parent = HudFrame

    local ABCorner = Instance.new("UICorner")
    ABCorner.CornerRadius = UDim.new(0, 5)
    ABCorner.Parent = AddBtn

    self:Connect(AddBtn.MouseButton1Click, function()
        if moduleData.MobileButton then
            for index, widget in ipairs(self.MobileButtons) do
                if widget == moduleData.MobileButton.Widget then table.remove(self.MobileButtons, index) break end
            end
            moduleData.MobileButton.Destroy()
            moduleData.MobileButton = nil
            AddBtn.Text = "+ Кнопка"
            AddBtn.TextColor3 = THEME.TextSecondary
        else
            local Widget = Instance.new("TextButton")
            Widget.Name = "HudBtn_" .. moduleData.Name
            Widget.Size = UDim2.new(0, 72, 0, 34)
            Widget.Position = UDim2.new(0.85, 0, 0.25 + (#self.MobileButtons * 0.08), 0)
            Widget.BackgroundColor3 = THEME.Background
            Widget.Text = moduleData.Name:sub(1, 8)
            Widget.TextColor3 = moduleData.State and THEME.Accent or THEME.TextSecondary
            Widget.Font = Enum.Font.GothamMedium
            Widget.TextSize = 10
            Widget.Parent = self.ScreenGui

            local WCorner = Instance.new("UICorner")
            WCorner.CornerRadius = UDim.new(0, 7)
            WCorner.Parent = Widget

            local WStroke = Instance.new("UIStroke")
            WStroke.Color = moduleData.State and THEME.Accent or THEME.StrokeSubtle
            WStroke.Thickness = 1.4
            WStroke.Parent = Widget

            makeDraggable(self, Widget, Widget)

            self:Connect(Widget.MouseButton1Click, function()
                moduleData.Toggle()
            end)

            moduleData.MobileButton = {
                Widget = Widget,
                UpdateVisual = function(st)
                    tween(Widget, {TextColor3 = st and THEME.Accent or THEME.TextSecondary}, 0.15)
                    tween(WStroke, {Color = st and THEME.Accent or THEME.StrokeSubtle}, 0.15)
                end,
                Destroy = function()
                    Widget:Destroy()
                end
            }
            table.insert(self.MobileButtons, Widget)
            AddBtn.Text = "Убрать"
            AddBtn.TextColor3 = THEME.Accent
        end
    end)

    table.insert(moduleData.Settings, HudFrame)
end

function NorthDLC:AddSlider(moduleData, config)
    config = config or {}
    local Name = config.Name or "Value"
    local Min = config.Min or 0
    local Max = config.Max or 100
    local Default = math.clamp(config.Default or Min, Min, Max)
    local Callback = config.Callback or function() end

    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 48)
    SliderFrame.BackgroundColor3 = THEME.CardIdle
    SliderFrame.Visible = false
    SliderFrame.Parent = self.SettingsScroll

    local SCorner = Instance.new("UICorner")
    SCorner.CornerRadius = UDim.new(0, 7)
    SCorner.Parent = SliderFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0.7, 0, 0, 16)
    NameLabel.Position = UDim2.new(0, 12, 0, 6)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Name
    NameLabel.TextColor3 = THEME.TextSecondary
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextSize = 11
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = SliderFrame

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(0.3, -12, 0, 16)
    ValLabel.Position = UDim2.new(0.7, 0, 0, 6)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(Default)
    ValLabel.TextColor3 = THEME.Accent
    ValLabel.Font = Enum.Font.GothamMedium
    ValLabel.TextSize = 11
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValLabel.Parent = SliderFrame

    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(1, -24, 0, 6)
    Track.Position = UDim2.new(0, 12, 0, 30)
    Track.BackgroundColor3 = THEME.SearchBg
    Track.Text = ""
    Track.AutoButtonColor = false
    Track.Parent = SliderFrame

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = Track

    local Fill = Instance.new("Frame")
    local initialScale = (Default - Min) / (Max - Min)
    Fill.Size = UDim2.new(initialScale, 0, 1, 0)
    Fill.BackgroundColor3 = THEME.Accent
    Fill.Parent = Track

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local isDragging = false
    local function updateValue(input)
        local posX = input.Position.X
        local trackAbsPos = Track.AbsolutePosition.X
        local trackAbsSize = Track.AbsoluteSize.X
        local ratio = math.clamp((posX - trackAbsPos) / trackAbsSize, 0, 1)
        local rawVal = Min + (Max - Min) * ratio
        local finalVal = math.floor(rawVal * 10) / 10

        Fill.Size = UDim2.new(ratio, 0, 1, 0)
        ValLabel.Text = tostring(finalVal)
        pcall(Callback, finalVal)
    end

    self:Connect(Track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateValue(input)
        end
    end)

    self:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    self:Connect(UserInputService.InputChanged, function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input)
        end
    end)

    table.insert(moduleData.Settings, SliderFrame)
    return SliderFrame
end

function NorthDLC:AddDropdown(moduleData, config)
    config = config or {}
    local Name = config.Name or "Mode"
    local Options = config.Options or {"Mode 1", "Mode 2"}
    local Selected = config.Default or Options[1]
    local Callback = config.Callback or function() end

    local DropFrame = Instance.new("Frame")
    DropFrame.Size = UDim2.new(1, 0, 0, 52)
    DropFrame.BackgroundColor3 = THEME.CardIdle
    DropFrame.ClipsDescendants = true
    DropFrame.Visible = false
    DropFrame.Parent = self.SettingsScroll

    local DropCorner = Instance.new("UICorner")
    DropCorner.CornerRadius = UDim.new(0, 7)
    DropCorner.Parent = DropFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -24, 0, 16)
    Title.Position = UDim2.new(0, 12, 0, 6)
    Title.BackgroundTransparency = 1
    Title.Text = Name
    Title.TextColor3 = THEME.TextMuted
    Title.Font = Enum.Font.Gotham
    Title.TextSize = 10
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = DropFrame

    local SelectBtn = Instance.new("TextButton")
    SelectBtn.Size = UDim2.new(1, -24, 0, 24)
    SelectBtn.Position = UDim2.new(0, 12, 0, 23)
    SelectBtn.BackgroundColor3 = THEME.SearchBg
    SelectBtn.AutoButtonColor = false
    SelectBtn.Text = ""
    SelectBtn.Parent = DropFrame

    local SBCorner = Instance.new("UICorner")
    SBCorner.CornerRadius = UDim.new(0, 5)
    SBCorner.Parent = SelectBtn

    local SelText = Instance.new("TextLabel")
    SelText.Size = UDim2.new(1, -24, 1, 0)
    SelText.Position = UDim2.new(0, 8, 0, 0)
    SelText.BackgroundTransparency = 1
    SelText.Text = Selected
    SelText.TextColor3 = THEME.TextPrimary
    SelText.Font = Enum.Font.GothamMedium
    SelText.TextSize = 11
    SelText.TextXAlignment = Enum.TextXAlignment.Left
    SelText.Parent = SelectBtn

    local ArrowImg = Instance.new("ImageLabel")
    ArrowImg.Size = UDim2.new(0, 12, 0, 12)
    ArrowImg.Position = UDim2.new(1, -18, 0.5, -6)
    ArrowImg.BackgroundTransparency = 1
    ArrowImg.Image = ICONS.ChevronDown
    ArrowImg.ImageColor3 = THEME.TextMuted
    ArrowImg.Parent = SelectBtn

    local OptionsContainer = Instance.new("Frame")
    OptionsContainer.Size = UDim2.new(1, -24, 0, #Options * 26)
    OptionsContainer.Position = UDim2.new(0, 12, 0, 52)
    OptionsContainer.BackgroundTransparency = 1
    OptionsContainer.Parent = DropFrame

    local OptLayout = Instance.new("UIListLayout")
    OptLayout.Padding = UDim.new(0, 3)
    OptLayout.Parent = OptionsContainer

    local optionButtons = {}
    local isExpanded = false

    local function updateDropdownVisuals()
        for optName, btn in pairs(optionButtons) do
            if optName == Selected then
                btn.TextColor3 = THEME.Accent
            else
                btn.TextColor3 = THEME.TextSecondary
            end
        end
    end

    local function toggleExpand()
        isExpanded = not isExpanded
        tween(ArrowImg, {Rotation = isExpanded and 180 or 0}, 0.2)
        local targetHeight = isExpanded and (56 + #Options * 29) or 52
        tween(DropFrame, {Size = UDim2.new(1, 0, 0, targetHeight)}, 0.2)
    end

    self:Connect(SelectBtn.MouseButton1Click, toggleExpand)

    for _, opt in ipairs(Options) do
        local OptBtn = Instance.new("TextButton")
        OptBtn.Size = UDim2.new(1, 0, 0, 26)
        OptBtn.BackgroundColor3 = THEME.SearchBg
        OptBtn.Text = "  " .. opt
        OptBtn.TextColor3 = (opt == Selected) and THEME.Accent or THEME.TextSecondary
        OptBtn.Font = Enum.Font.Gotham
        OptBtn.TextSize = 11
        OptBtn.TextXAlignment = Enum.TextXAlignment.Left
        OptBtn.Parent = OptionsContainer

        local OptCorner = Instance.new("UICorner")
        OptCorner.CornerRadius = UDim.new(0, 5)
        OptCorner.Parent = OptBtn

        optionButtons[opt] = OptBtn

        self:Connect(OptBtn.MouseButton1Click, function()
            Selected = opt
            SelText.Text = opt
            updateDropdownVisuals()
            toggleExpand()
            pcall(Callback, opt)
        end)
    end

    table.insert(self.Dropdowns, {
        UpdateColors = updateDropdownVisuals
    })

    table.insert(moduleData.Settings, DropFrame)
    return DropFrame
end

function NorthDLC:AddSubToggle(moduleData, config)
    config = config or {}
    local Name = config.Name or "Option"
    local Default = config.Default or false
    local Callback = config.Callback or function() end

    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
    ToggleFrame.BackgroundColor3 = THEME.CardIdle
    ToggleFrame.Visible = false
    ToggleFrame.Parent = self.SettingsScroll

    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(0, 7)
    TCorner.Parent = ToggleFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -50, 1, 0)
    NameLabel.Position = UDim2.new(0, 12, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Name
    NameLabel.TextColor3 = THEME.TextSecondary
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextSize = 11
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = ToggleFrame

    local Switch = Instance.new("TextButton")
    Switch.Size = UDim2.new(0, 32, 0, 18)
    Switch.Position = UDim2.new(1, -42, 0.5, -9)
    Switch.BackgroundColor3 = Default and THEME.Accent or THEME.SearchBg
    Switch.AutoButtonColor = false
    Switch.Text = ""
    Switch.Parent = ToggleFrame

    local SCorner2 = Instance.new("UICorner")
    SCorner2.CornerRadius = UDim.new(1, 0)
    SCorner2.Parent = Switch

    local Dot = Instance.new("Frame")
    Dot.Size = UDim2.new(0, 14, 0, 14)
    Dot.Position = Default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Dot.Parent = Switch

    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = Dot

    local state = Default
    self:Connect(Switch.MouseButton1Click, function()
        state = not state
        if state then
            tween(Switch, {BackgroundColor3 = THEME.Accent}, 0.15)
            tween(Dot, {Position = UDim2.new(1, -16, 0.5, -7)}, 0.15)
        else
            tween(Switch, {BackgroundColor3 = THEME.SearchBg}, 0.15)
            tween(Dot, {Position = UDim2.new(0, 2, 0.5, -7)}, 0.15)
        end
        pcall(Callback, state)
    end)

    table.insert(moduleData.Settings, ToggleFrame)
    return ToggleFrame
end

-- ═════════════════════════════════════════════════════════════
-- СТАРТ ХАБА «NorthDLC»
-- ═════════════════════════════════════════════════════════════
local Hub = NorthDLC.CreateWindow({
    Title = "NorthDLC",
})

local CombatTab   = Hub:AddCategory({Name = "Combat",   IconType = "Combat",   Description = "боевые модули и ассисты"})
local MovementTab = Hub:AddCategory({Name = "Movement", IconType = "Movement", Description = "перемещение и скорость"})
local RenderTab   = Hub:AddCategory({Name = "Render",   IconType = "Render",   Description = "визуальные элементы игры"})
local PlayerTab   = Hub:AddCategory({Name = "Player",   IconType = "Player",   Description = "модификации персонажа"})
local MiscTab     = Hub:AddCategory({Name = "Misc",     IconType = "Misc",     Description = "дополнительные утилиты"})

-- ─────────────────────────────────────────────────────────────
-- FLY: PHYSICS / VELOCITY / CFRAME / AIRWALK
-- ─────────────────────────────────────────────────────────────
local FlyActive = false
local FlyMode = "Smooth Physics"
local FlySpeed = 50
local FlyAcceleration = 100
local FlyCameraRelative = true
local FlyFaceCamera = false
local FlyDiagnostics = false
local FlyConnection, FlyMonitorConnection
local FlyModule
local FlyHumanoid, FlyRoot, FlyHumanoidState
local FlyObjects = {}
local FlyTouchUp, FlyTouchDown = false, false
local InvisibleFloor
local FlyMobileControls = Instance.new("Frame")
FlyMobileControls.Name = "FlyHeightControls"
FlyMobileControls.Size = UDim2.fromOffset(52, 116)
FlyMobileControls.Position = UDim2.new(1, -76, 0.5, -58)
FlyMobileControls.BackgroundTransparency = 1
FlyMobileControls.Visible = false
FlyMobileControls.Parent = Hub.ScreenGui

local function addFlyHeightButton(text, y, setHeld)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(52, 52)
    button.Position = UDim2.fromOffset(0, y)
    button.BackgroundColor3 = THEME.Background
    button.Text = text
    button.TextColor3 = THEME.TextPrimary
    button.TextSize = 24
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Parent = FlyMobileControls
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    local activeInput
    Hub:Connect(button.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            activeInput = input
            setHeld(true)
        end
    end)
    Hub:Connect(UserInputService.InputEnded, function(input)
        if input == activeInput then activeInput = nil setHeld(false) end
    end)
end
addFlyHeightButton("↑", 0, function(held) FlyTouchUp = held end)
addFlyHeightButton("↓", 64, function(held) FlyTouchDown = held end)
Hub:Connect(UserInputService.WindowFocusReleased, function()
    FlyTouchUp, FlyTouchDown = false, false
end)

local function cleanupFlyPhysics()
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if FlyMonitorConnection then FlyMonitorConnection:Disconnect() FlyMonitorConnection = nil end
    for _, object in ipairs(FlyObjects) do object:Destroy() end
    table.clear(FlyObjects)
    InvisibleFloor = nil
    if FlyRoot and FlyRoot.Parent then
        FlyRoot.AssemblyLinearVelocity = Vector3.zero
        FlyRoot.AssemblyAngularVelocity = Vector3.zero
    end
    if FlyHumanoid and FlyHumanoid.Parent and FlyHumanoidState then
        FlyHumanoid.PlatformStand = FlyHumanoidState.PlatformStand
        FlyHumanoid.AutoRotate = FlyHumanoidState.AutoRotate
        FlyHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, FlyHumanoidState.FallingDown)
        FlyHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, FlyHumanoidState.Ragdoll)
        if not FlyHumanoidState.PlatformStand and FlyHumanoid.Health > 0 then
            FlyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
    FlyHumanoid, FlyRoot, FlyHumanoidState = nil, nil, nil
    FlyTouchUp, FlyTouchDown = false, false
    FlyMobileControls.Visible = false
end

local function getFlyVerticalInput()
    local up, down = FlyTouchUp, FlyTouchDown
    if not UserInputService:GetFocusedTextBox() then
        up = up or UserInputService:IsKeyDown(Enum.KeyCode.Space)
        down = down or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
    end
    return (up and 1 or 0) - (down and 1 or 0)
end

local function getFlyDirection(moveDirection, cameraCF, vertical)
    local direction = moveDirection
    if FlyCameraRelative and cameraCF then
        -- MoveDirection is world-space: recover camera input before adding pitch.
        local flatLook = Vector3.new(cameraCF.LookVector.X, 0, cameraCF.LookVector.Z)
        if flatLook.Magnitude > 0.001 then
            flatLook = flatLook.Unit
            local flatRight = flatLook:Cross(Vector3.yAxis)
            direction = cameraCF.LookVector * moveDirection:Dot(flatLook)
                + flatRight * moveDirection:Dot(flatRight)
        end
    end
    direction = direction + Vector3.yAxis * vertical
    if direction.Magnitude > 1 then direction = direction.Unit end
    return direction
end

local function approachFlyVelocity(current, target, dt)
    local delta = target - current
    local maxChange = FlyAcceleration * dt
    if delta.Magnitude <= maxChange then return target end
    return current + delta.Unit * maxChange
end

local function runFlyEngine()
    cleanupFlyPhysics()
    if not FlyActive or Hub.Destroyed then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    FlyHumanoid, FlyRoot = hum, hrp
    FlyHumanoidState = {
        PlatformStand = hum.PlatformStand,
        AutoRotate = hum.AutoRotate,
        FallingDown = hum:GetStateEnabled(Enum.HumanoidStateType.FallingDown),
        Ragdoll = hum:GetStateEnabled(Enum.HumanoidStateType.Ragdoll),
    }
    local function own(object)
        table.insert(FlyObjects, object)
        return object
    end
    local velocity, orientation
    local adaptive = FlyMode == "Adaptive (Test)"
    local constraintFlight = FlyMode == "Smooth Physics" or adaptive
    local currentVelocity = Vector3.zero
    local recoveryRemaining, recoveryElapsed, recoveryAttempts = 0, 0, 0
    local adaptiveSpeedScale = 1
    local startRotation = hrp.CFrame.Rotation
    local graceRemaining = 0.6
    local floorY
    local function setFlightState(enabled)
        hum.PlatformStand = enabled or FlyHumanoidState.PlatformStand
        hum.AutoRotate = not enabled and FlyHumanoidState.AutoRotate
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled and FlyHumanoidState.FallingDown)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled and FlyHumanoidState.Ragdoll)
    end
    local function stopAdaptive(reason)
        warn("[NorthDLC Fly] Adaptive stopped: " .. reason)
        if FlyModule then
            FlyModule.SetState(false)
        else
            FlyActive = false
            cleanupFlyPhysics()
        end
    end
    local function yieldFlight(reason)
        if not adaptive or recoveryRemaining > 0 then return end
        recoveryAttempts = recoveryAttempts + 1
        if recoveryAttempts > 3 then stopAdaptive("repeated corrections") return end
        recoveryRemaining, recoveryElapsed = 0.8, 0
        adaptiveSpeedScale = adaptiveSpeedScale * 0.65
        currentVelocity = Vector3.zero
        velocity.Enabled = false
        orientation.Enabled = false
        setFlightState(false)
        warn(string.format("[NorthDLC Fly] Adaptive pause %d/3: %s; next speed cap=%.1f",
            recoveryAttempts, reason, FlySpeed * adaptiveSpeedScale))
    end
    if FlyMode == "AirWalk" then
        InvisibleFloor = own(Instance.new("Part"))
        InvisibleFloor.Name = "NorthDLC_AirWalk"
        InvisibleFloor.Size = Vector3.new(8, 1, 8)
        InvisibleFloor.Transparency = 1
        InvisibleFloor.Anchored = true
        InvisibleFloor.CanCollide = true
        InvisibleFloor.CanTouch = false
        InvisibleFloor.CanQuery = false
        -- R6 HipHeight excludes the legs; R15 already includes them.
        local leg = hum.RigType == Enum.HumanoidRigType.R6 and char:FindFirstChild("Left Leg")
        local footDistance = hum.HipHeight + hrp.Size.Y * 0.5 + (leg and leg.Size.Y or 0)
        floorY = hrp.Position.Y - footDistance - 0.5
        InvisibleFloor.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z)
        InvisibleFloor.Parent = Workspace
    else
        setFlightState(true)
        if constraintFlight then
            local attachment = own(Instance.new("Attachment"))
            attachment.Name = "NorthDLC_FlyAttachment"
            attachment.Parent = hrp
            velocity = own(Instance.new("LinearVelocity"))
            velocity.Attachment0 = attachment
            velocity.RelativeTo = Enum.ActuatorRelativeTo.World
            velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            velocity.ForceLimitsEnabled = true
            velocity.MaxForce = hrp.AssemblyMass * (Workspace.Gravity + FlyAcceleration * 2 + 50)
            velocity.VectorVelocity = Vector3.zero
            velocity.Parent = hrp
            orientation = own(Instance.new("AlignOrientation"))
            orientation.Attachment0 = attachment
            orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
            orientation.MaxTorque = 1000000
            orientation.MaxAngularVelocity = 20
            orientation.Responsiveness = 18
            orientation.CFrame = hrp.CFrame.Rotation
            orientation.Parent = hrp
        else
            local attachment = own(Instance.new("Attachment"))
            attachment.Name = "NorthDLC_FlyAttachment"
            attachment.Parent = hrp
            local gravityForce = own(Instance.new("VectorForce"))
            gravityForce.Name = "NorthDLC_FlyGravity"
            gravityForce.Attachment0 = attachment
            gravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
            gravityForce.ApplyAtCenterOfMass = true
            gravityForce.Force = Vector3.yAxis * hrp.AssemblyMass * Workspace.Gravity
            gravityForce.Parent = hrp
            velocity = gravityForce
        end
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char, FlyMobileControls}
    rayParams.RespectCanCollide = true
    FlyMobileControls.Visible = UserInputService.TouchEnabled
    local mismatchTime, diagnosticCooldown = 0, 0
    local previousPosition = hrp.Position
    local previousVelocity = hrp.AssemblyLinearVelocity
    if FlyDiagnostics then
        print("[NorthDLC Fly] Start", FlyMode, "PlaceId", game.PlaceId, "GameId", game.GameId)
    end
    FlyConnection = RunService.PreSimulation:Connect(function(dt)
        if not FlyActive or Hub.Destroyed or LocalPlayer.Character ~= char or not hrp.Parent or hum.Health <= 0 then
            cleanupFlyPhysics()
            return
        end
        if adaptive and recoveryRemaining > 0 then
            recoveryElapsed = recoveryElapsed + dt
            recoveryRemaining = math.max(0, recoveryRemaining - dt)
            if recoveryRemaining == 0 then
                if hrp.Anchored or hum.Sit then
                    if recoveryElapsed >= 2 then stopAdaptive("character remains anchored or seated") return end
                    recoveryRemaining = 0.1
                else
                    currentVelocity = Vector3.zero
                    startRotation = hrp.CFrame.Rotation
                    velocity.VectorVelocity = Vector3.zero
                    velocity.Enabled, orientation.Enabled = true, true
                    setFlightState(true)
                    graceRemaining = 0.6
                    print("[NorthDLC Fly] Adaptive resumed")
                end
            end
            return
        end
        dt = math.clamp(dt, 0, 0.1)
        if constraintFlight then
            velocity.MaxForce = hrp.AssemblyMass * (Workspace.Gravity + FlyAcceleration * 2 + 50)
        elseif velocity then
            velocity.Force = Vector3.yAxis * hrp.AssemblyMass * Workspace.Gravity
        end
        local vertical = getFlyVerticalInput()
        if FlyMode == "AirWalk" then
            floorY = floorY + vertical * math.min(FlySpeed, 12) * dt
            InvisibleFloor.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z)
            return
        end
        local camera = Workspace.CurrentCamera
        local camCF = camera and camera.CFrame
        local direction = getFlyDirection(hum.MoveDirection, camCF, vertical)
        currentVelocity = approachFlyVelocity(currentVelocity, direction * FlySpeed * adaptiveSpeedScale, dt)
        if constraintFlight then
            velocity.VectorVelocity = currentVelocity
            if FlyFaceCamera and camCF then
                local facing = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                if facing.Magnitude > 0.001 then orientation.CFrame = CFrame.lookAt(Vector3.zero, facing.Unit) end
            else
                orientation.CFrame = startRotation
            end
        elseif FlyMode == "Velocity" then
            hrp.AssemblyLinearVelocity = currentVelocity
        elseif FlyMode == "CFrame" then
            local step = currentVelocity * dt
            if step.Magnitude > 0.001 then
                -- Center ray reduces wall crossings; it is not a character-volume sweep.
                local hit = Workspace:Raycast(hrp.Position, step.Unit * (step.Magnitude + 1.5), rayParams)
                if hit then
                    step = step.Unit * math.min(step.Magnitude, math.max(0, hit.Distance - 1.5))
                    currentVelocity = Vector3.zero
                end
                hrp.CFrame = hrp.CFrame + step
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    FlyMonitorConnection = RunService.PostSimulation:Connect(function(dt)
        if not FlyActive or Hub.Destroyed or LocalPlayer.Character ~= char or not hrp.Parent or hum.Health <= 0 then
            cleanupFlyPhysics()
            return
        end
        local actual = hrp.AssemblyLinearVelocity
        -- Compare actual displacement with observed motion, rather than assuming
        -- every speed mismatch is a rollback. Collisions/impulses can also differ.
        local positionError = (hrp.Position - previousPosition - (previousVelocity + actual) * (dt * 0.5)).Magnitude
        previousPosition, previousVelocity = hrp.Position, actual
        diagnosticCooldown = math.max(0, diagnosticCooldown - dt)
        graceRemaining = math.max(0, graceRemaining - dt)
        if FlyMode == "AirWalk" or recoveryRemaining > 0 or graceRemaining > 0 then
            mismatchTime = 0
            return
        end
        local mismatch = FlyMode == "CFrame" and 0 or (actual - currentVelocity).Magnitude
        local stateReset = hrp.Anchored or not hum.PlatformStand
        if mismatch > math.max(8, currentVelocity.Magnitude * 0.6) or stateReset then
            mismatchTime = mismatchTime + dt
        else
            mismatchTime = 0
        end
        -- Ignore long frames when looking for discontinuous position changes.
        local discontinuity = dt > 0 and dt <= 0.1 and positionError > math.max(6, FlySpeed * dt * 2.5)
        local reason = stateReset and "character state changed" or discontinuity and "position discontinuity" or "sustained velocity mismatch"
        if FlyDiagnostics and diagnosticCooldown == 0 and (mismatchTime >= 1 or discontinuity) then
            warn(string.format(
                "[NorthDLC Fly] Movement mismatch; mode=%s reason=%s positionError=%.2f actual=%s target=%s state=%s anchored=%s platformStand=%s. Collision or external correction possible; network ownership is unconfirmed.",
                FlyMode, reason, positionError, tostring(actual), tostring(currentVelocity),
                hum:GetState().Name, tostring(hrp.Anchored), tostring(hum.PlatformStand)
            ))
            diagnosticCooldown = 5
        end
        if adaptive and (stateReset or discontinuity or mismatchTime >= 1) then
            mismatchTime = 0
            yieldFlight(reason)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- ДВИЖОК NoClip С 4 РЕЖИМАМИ (ДЛЯ DANDY'S WORLD И ДРУГИХ)
-- ─────────────────────────────────────────────────────────────
local NoClipActive = false
local NoClipMode = "CFrame Spoof"
local NoClipConnection = nil
local NoClipOriginal = {}

local function cleanupNoClip()
    if NoClipConnection then NoClipConnection:Disconnect() NoClipConnection = nil end
    for part, original in pairs(NoClipOriginal) do
        if part.Parent then
            part.CanCollide = original.CanCollide
            part.CustomPhysicalProperties = original.CustomPhysicalProperties
        end
    end
    table.clear(NoClipOriginal)
end

local function runNoClipEngine()
    cleanupNoClip()
    if not NoClipActive then return end

    NoClipConnection = RunService.Stepped:Connect(function()
        if not NoClipActive then return end
        local char = LocalPlayer.Character
        if not char then return end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and not NoClipOriginal[part] then
                NoClipOriginal[part] = {
                    CanCollide = part.CanCollide,
                    CustomPhysicalProperties = part.CustomPhysicalProperties,
                }
            end
        end

        if NoClipMode == "Collision Phase" then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        elseif NoClipMode == "CFrame Spoof" then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
            if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (hum.MoveDirection * 0.25)
            end
        elseif NoClipMode == "Physics Bypass" then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0, 0, 0, 0)
                end
            end
        elseif NoClipMode == "Velocity Clip" then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = hum.MoveDirection * 35
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- РЕГИСТРАЦИЯ МОДУЛЕЙ MOVEMENT
-- ─────────────────────────────────────────────────────────────
FlyModule = Hub:AddModule(MovementTab, {
    Name = "Fly",
    Description = "Плавный полёт: Space / Shift или экранные стрелки",
    Default = false,
    Callback = function(enabled)
        FlyActive = enabled
        if enabled then runFlyEngine() else cleanupFlyPhysics() end
    end
})

Hub:AddDropdown(FlyModule, {
    Name = "Mode",
    Options = {"Smooth Physics", "Velocity", "CFrame", "AirWalk", "Adaptive (Test)"},
    Default = "Smooth Physics",
    Callback = function(newMode)
        FlyMode = newMode
        if FlyActive then runFlyEngine() end
    end
})

Hub:AddSlider(FlyModule, {
    Name = "Fly Speed",
    Min = 10,
    Max = 200,
    Default = 50,
    Callback = function(val)
        FlySpeed = val
    end
})

Hub:AddSlider(FlyModule, {
    Name = "Acceleration",
    Min = 20,
    Max = 300,
    Default = 100,
    Callback = function(value) FlyAcceleration = value end,
})
Hub:AddSubToggle(FlyModule, {
    Name = "Следовать наклону камеры",
    Default = true,
    Callback = function(enabled) FlyCameraRelative = enabled end,
})
Hub:AddSubToggle(FlyModule, {
    Name = "Поворачивать персонажа за камерой",
    Default = false,
    Callback = function(enabled) FlyFaceCamera = enabled end,
})
Hub:AddSubToggle(FlyModule, {
    Name = "Fly диагностика (консоль)",
    Default = false,
    Callback = function(enabled) FlyDiagnostics = enabled end,
})

local SpeedValue = 32
local SpeedHumanoid, OriginalWalkSpeed
local Speed = Hub:AddModule(MovementTab, {
    Name = "Speed / WalkSpeed",
    Description = "Увеличение скорости ходьбы игрока",
    Callback = function(enabled)
        if SpeedHumanoid and SpeedHumanoid.Parent and OriginalWalkSpeed ~= nil then
            SpeedHumanoid.WalkSpeed = OriginalWalkSpeed
        end
        SpeedHumanoid, OriginalWalkSpeed = nil, nil
        if enabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                SpeedHumanoid, OriginalWalkSpeed = hum, hum.WalkSpeed
                hum.WalkSpeed = SpeedValue
            end
        end
    end
})
Hub:AddSlider(Speed, {
    Name = "Speed Multiplier",
    Min = 16,
    Max = 120,
    Default = 32,
    Callback = function(val)
        SpeedValue = val
        if Speed.State and SpeedHumanoid and SpeedHumanoid.Parent then SpeedHumanoid.WalkSpeed = val end
    end
})

-- ─────────────────────────────────────────────────────────────
-- РЕГИСТРАЦИЯ МОДУЛЕЙ PLAYER
-- ─────────────────────────────────────────────────────────────
local NoClipModule = Hub:AddModule(PlayerTab, {
    Name = "No Clip",
    Description = "Прохождение сквозь препятствия и двери",
    Default = false,
    Callback = function(enabled)
        NoClipActive = enabled
        runNoClipEngine()
    end
})

Hub:AddDropdown(NoClipModule, {
    Name = "Mode",
    Options = {"Collision Phase", "CFrame Spoof", "Physics Bypass", "Velocity Clip"},
    Default = "CFrame Spoof",
    Callback = function(newMode)
        NoClipMode = newMode
        runNoClipEngine()
    end
})

local JumpConnection
Hub:AddModule(PlayerTab, {
    Name = "Infinite Jump",
    Description = "Позволяет прыгать неограниченно в воздухе",
    Callback = function(enabled)
        if JumpConnection then JumpConnection:Disconnect() JumpConnection = nil end
        if enabled then
            JumpConnection = UserInputService.JumpRequest:Connect(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    end
})

-- ─────────────────────────────────────────────────────────────
-- РЕГИСТРАЦИЯ МОДУЛЕЙ RENDER
-- ─────────────────────────────────────────────────────────────
local ClientTheme = Hub:AddModule(RenderTab, {
    Name = "Client Theme",
    Description = "Изменение цветовой схемы и акцента интерфейса",
    Default = true,
})
Hub:AddDropdown(ClientTheme, {
    Name = "Accent Color",
    Options = {"Amber Gold", "Neon Cyan", "Acid Lime", "Royal Purple", "Crimson Red"},
    Default = "Amber Gold",
    Callback = function(themeName)
        Hub:SetTheme(themeName)
    end
})

local OriginalLighting
local FullBright = Hub:AddModule(RenderTab, {
    Name = "Full Bright",
    Description = "Выкручивает яркость игры на максимум, хорошо видно в темноте",
    Default = false,
    Callback = function(enabled)
        if enabled then
            OriginalLighting = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime}
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
        elseif OriginalLighting then
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
            OriginalLighting = nil
        end
    end
})

local TNTTimer = Hub:AddModule(RenderTab, {
    Name = "TNT Timer",
    Description = "Показывает время до взрыва активного динамита",
})

local Crosshair = Hub:AddModule(RenderTab, {
    Name = "Crosshair",
    Description = "Изменяет внешний вид прицела",
})
Hub:AddDropdown(Crosshair, {
    Name = "Style",
    Options = {"Dot", "Classic Cross", "Circle", "Chevron"},
    Default = "Classic Cross"
})
Hub:AddSlider(Crosshair, {
    Name = "Size",
    Min = 4,
    Max = 30,
    Default = 12
})

local FreeLook = Hub:AddModule(RenderTab, {
    Name = "Free Look",
    Description = "Позволяет осмотреться от третьего лица без отображения другим игрокам",
})

local ChinaHat = Hub:AddModule(RenderTab, {
    Name = "China Hat",
    Description = "Отображает китайскую шляпу на модели персонажа",
})

local Interface = Hub:AddModule(RenderTab, {
    Name = "Interface",
    Description = "Добавляет дополнительные элементы худа и индикаторы",
})

-- ─────────────────────────────────────────────────────────────
-- РЕГИСТРАЦИЯ МОДУЛЕЙ COMBAT
-- ─────────────────────────────────────────────────────────────
local KillAura = Hub:AddModule(CombatTab, {
    Name = "Kill Aura",
    Description = "Автоматическая атака ближайших целей",
    Callback = function(enabled) print("[NorthDLC] Kill Aura:", enabled) end
})
Hub:AddDropdown(KillAura, {
    Name = "Target Mode",
    Options = {"Nearest", "Lowest HP", "Crosshair FOV"},
    Default = "Nearest",
})
Hub:AddSlider(KillAura, {
    Name = "Attack Range",
    Min = 5,
    Max = 30,
    Default = 16,
})
Hub:AddSubToggle(KillAura, {
    Name = "Silent Rotation",
    Default = true,
})

-- ─────────────────────────────────────────────────────────────
-- РЕГИСТРАЦИЯ МОДУЛЕЙ MISC
-- ─────────────────────────────────────────────────────────────
Hub:AddModule(MiscTab, {
    Name = "Self Destruct",
    Description = "Полная очистка и скрытие следов чита из игры",
    Callback = function(enabled)
        if enabled then Hub:Destroy() end
    end
})

Hub.OnDestroy = function()
    FlyActive = false
    NoClipActive = false
    cleanupFlyPhysics()
    cleanupNoClip()
    if JumpConnection then JumpConnection:Disconnect() JumpConnection = nil end
end

Hub:Connect(LocalPlayer.CharacterRemoving, function()
    cleanupFlyPhysics()
    cleanupNoClip()
end)
Hub:Connect(LocalPlayer.CharacterAdded, function(character)
    local hum = character:WaitForChild("Humanoid", 10)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if Hub.Destroyed or LocalPlayer.Character ~= character then return end
    if FlyActive and hum and root then runFlyEngine() end
    if NoClipActive then runNoClipEngine() end
    if Speed.State and hum then Speed.Callback(true) end
end)

print("[NorthDLC v7] Загружено. Fly: Smooth Physics / Velocity / CFrame / AirWalk / Adaptive (Test).")


