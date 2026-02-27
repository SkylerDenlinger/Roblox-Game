local CommonWidgets = {}

function CommonWidgets.new(themeColors, tabThemeByName)
	local widgets = {}

	function widgets.styleSharpOutline(frame, color, transparency)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Transparency = transparency
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end

	function widgets.addButtonChrome(button, topColor, bottomColor)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(0.55, Color3.new(
				math.clamp((topColor.R + bottomColor.R) * 0.5, 0, 1),
				math.clamp((topColor.G + bottomColor.G) * 0.5, 0, 1),
				math.clamp((topColor.B + bottomColor.B) * 0.5, 0, 1)
			)),
			ColorSequenceKeypoint.new(1, bottomColor),
		})
		gradient.Rotation = 90
		gradient.Parent = button

		local topEdge = Instance.new("Frame")
		topEdge.Name = "TopEdge"
		topEdge.Size = UDim2.new(1, -6, 0, 1)
		topEdge.Position = UDim2.new(0, 3, 0, 2)
		topEdge.BackgroundColor3 = themeColors.white
		topEdge.BackgroundTransparency = 0.45
		topEdge.BorderSizePixel = 0
		topEdge.ZIndex = button.ZIndex + 1
		topEdge.Parent = button

		local innerBorder = Instance.new("Frame")
		innerBorder.Name = "InnerBorder"
		innerBorder.Size = UDim2.new(1, -6, 1, -6)
		innerBorder.Position = UDim2.new(0, 3, 0, 3)
		innerBorder.BackgroundTransparency = 1
		innerBorder.BorderSizePixel = 0
		innerBorder.ZIndex = button.ZIndex + 1
		innerBorder.Parent = button

		local innerStroke = Instance.new("UIStroke")
		innerStroke.Color = themeColors.white
		innerStroke.Thickness = 1
		innerStroke.Transparency = 0.62
		innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		innerStroke.Parent = innerBorder
	end

	function widgets.makeTextLabel(parent, name, text, size, position, font, textSize, color, alignment)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Text = text
		label.Size = size
		label.Position = position
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextSize = textSize
		label.TextColor3 = color
		label.TextXAlignment = alignment or Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = parent
		return label
	end

	function widgets.makeList(parent, name, size, position)
		local list = Instance.new("ScrollingFrame")
		list.Name = name
		list.Size = size
		list.Position = position
		list.BackgroundColor3 = themeColors.charcoal
		list.BackgroundTransparency = 0.18
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		list.Parent = parent
		widgets.styleSharpOutline(list, themeColors.black, 0)

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = list

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Parent = list

		return list
	end

	function widgets.clearListRows(list)
		for _, child in ipairs(list:GetChildren()) do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
	end

	function widgets.createActionButton(parent, name, text, size, position, bgColor, outlineColor)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Text = text
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = bgColor
		button.BackgroundTransparency = 0.04
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBlack
		button.TextSize = 21
		button.TextColor3 = themeColors.white
		button.TextStrokeColor3 = themeColors.black
		button.TextStrokeTransparency = 0
		button.Parent = parent
		widgets.styleSharpOutline(button, outlineColor or themeColors.black, 0)
		widgets.addButtonChrome(
			button,
			Color3.new(
				math.clamp(bgColor.R + 0.15, 0, 1),
				math.clamp(bgColor.G + 0.15, 0, 1),
				math.clamp(bgColor.B + 0.15, 0, 1)
			),
			Color3.new(
				math.clamp(bgColor.R - 0.1, 0, 1),
				math.clamp(bgColor.G - 0.1, 0, 1),
				math.clamp(bgColor.B - 0.1, 0, 1)
			)
		)

		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 0.04
		end)
		button.MouseButton1Down:Connect(function()
			button.BackgroundTransparency = 0
		end)
		button.MouseButton1Up:Connect(function()
			button.BackgroundTransparency = 0
		end)

		return button
	end

	function widgets.createTabButton(parent, text)
		local tabTheme = tabThemeByName[text]
		local isHeroStyle = tabTheme ~= nil
		local baseTheme = tabTheme or tabThemeByName.PLAY

		local button = Instance.new("TextButton")
		button.Name = text .. "Tab"
		button.Size = UDim2.new(1, 0, 0, 62)
		button.BackgroundColor3 = isHeroStyle and baseTheme.base or themeColors.charcoal
		button.BackgroundTransparency = isHeroStyle and 0.04 or 0.18
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBlack
		button.Text = text
		button.TextColor3 = baseTheme.text or themeColors.white
		button.TextSize = isHeroStyle and 28 or 24
		button.TextStrokeColor3 = baseTheme.stroke or themeColors.black
		button.TextStrokeTransparency = 0
		button.Parent = parent

		widgets.styleSharpOutline(button, themeColors.black, 0)
		widgets.addButtonChrome(button, baseTheme.light, baseTheme.dark)

		if baseTheme.accent then
			local accentBar = Instance.new("Frame")
			accentBar.Name = "AccentBar"
			accentBar.Size = UDim2.new(0, 8, 1, -8)
			accentBar.Position = UDim2.new(1, -12, 0, 4)
			accentBar.BackgroundColor3 = baseTheme.accent
			accentBar.BorderSizePixel = 0
			accentBar.ZIndex = button.ZIndex + 1
			accentBar.Parent = button
		end

		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MinTextSize = 15
		sizeConstraint.MaxTextSize = 28
		sizeConstraint.Parent = button

		local hoverTransparency = 0
		local idleTransparency = isHeroStyle and 0.04 or 0.18
		local downTransparency = 0

		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = hoverTransparency
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = idleTransparency
		end)
		button.MouseButton1Down:Connect(function()
			button.BackgroundTransparency = downTransparency
		end)
		button.MouseButton1Up:Connect(function()
			button.BackgroundTransparency = hoverTransparency
		end)
		button.MouseButton1Click:Connect(function()
			print(("HomepageOverlay: %s clicked"):format(text))
		end)

		return button
	end

	return widgets
end

return CommonWidgets
