import AppKit
import Foundation

class PopoverController: NSViewController {
    let bt = BluetoothManager.shared
    
    var statusTextLabel: NSTextField!
    var leftBatLabel: NSTextField!
    var rightBatLabel: NSTextField!
    var caseBatLabel: NSTextField!
    
    var masterSwitch: NSSwitch!
    var ncStatusLabel: NSTextField!
    var ncSlider: NSSlider!
    var voiceFocusCheckbox: NSButton!
    
    var eqPopup: NSPopUpButton!
    var cbStatusLabel: NSTextField!
    var cbSlider: NSSlider!
    
    var ncDebounceTimer: Timer?
    var cbDebounceTimer: Timer?
    
    override func loadView() {
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 310, height: 460))
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        self.view = view
        
        setupUI()
    }
    
    func setupUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 18),
            mainStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -18),
            mainStack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -16)
        ])
        
        // ==========================================
        // 1. HEADER (Title & Status)
        // ==========================================
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        let iconView = NSImageView()
        iconView.image = ImageLoader.image(named: "wf_sp800n_color_00_01_sca", size: NSSize(width: 64, height: 64))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        
        let titleLabel = NSTextField(labelWithString: "Sony WF-SP800N")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        
        statusTextLabel = NSTextField(labelWithString: L10n.text("connecting"))
        statusTextLabel.font = NSFont.systemFont(ofSize: 11)
        statusTextLabel.textColor = .secondaryLabelColor
        
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(statusTextLabel)
        
        let refreshImg = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: L10n.text("refresh")) ?? NSImage()
        let refreshBtn = NSButton(image: refreshImg, target: self, action: #selector(onRefresh))
        refreshBtn.isBordered = false
        refreshBtn.toolTip = L10n.text("refreshReconnect")
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(refreshBtn)
        mainStack.addArrangedSubview(headerStack)
        
        // ==========================================
        // 2. BATTERY SECTION (3 Cards)
        // ==========================================
        let batStack = NSStackView()
        batStack.orientation = .horizontal
        batStack.distribution = .fillEqually
        batStack.spacing = 6
        batStack.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        let leftCard = makeBatteryCard(title: L10n.text("leftEarbud"), imageName: "wf_sp800n_color_00_01_left")
        leftBatLabel = leftCard.1
        let rightCard = makeBatteryCard(title: L10n.text("rightEarbud"), imageName: "wf_sp800n_color_00_01_right")
        rightBatLabel = rightCard.1
        let caseCard = makeBatteryCard(title: L10n.text("chargingCase"), imageName: "wf_sp800n_color_00_01_cradle")
        caseBatLabel = caseCard.1
        
        batStack.addArrangedSubview(leftCard.0)
        batStack.addArrangedSubview(rightCard.0)
        batStack.addArrangedSubview(caseCard.0)
        mainStack.addArrangedSubview(batStack)
        
        mainStack.addArrangedSubview(makeDivider())
        
        // ==========================================
        // 3. ORTAM SESİ KONTROLÜ (SONY MANTIĞI)
        // ==========================================
        let ncToggleStack = NSStackView()
        ncToggleStack.orientation = .horizontal
        ncToggleStack.alignment = .centerY
        ncToggleStack.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        let ncTitle = NSTextField(labelWithString: L10n.text("ambientControl"))
        ncTitle.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        
        masterSwitch = NSSwitch()
        masterSwitch.target = self
        masterSwitch.action = #selector(onMasterToggled(_:))
        
        let spacerNC = NSView()
        spacerNC.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        ncToggleStack.addArrangedSubview(ncTitle)
        ncToggleStack.addArrangedSubview(spacerNC)
        ncToggleStack.addArrangedSubview(masterSwitch)
        mainStack.addArrangedSubview(ncToggleStack)
        
        // Slider Container (Rounded Box using NSStackView)
        let sliderContainer = NSStackView()
        sliderContainer.orientation = .vertical
        sliderContainer.alignment = .leading
        sliderContainer.spacing = 6
        sliderContainer.wantsLayer = true
        sliderContainer.layer?.cornerRadius = 8
        sliderContainer.layer?.backgroundColor = panelBackgroundColor().cgColor
        sliderContainer.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        sliderContainer.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        ncStatusLabel = NSTextField(labelWithString: L10n.text("noiseCancelling"))
        ncStatusLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        ncStatusLabel.textColor = .systemBlue
        
        ncSlider = NSSlider(value: 0, minValue: 0, maxValue: 20, target: self, action: #selector(onNCSliderMoved(_:)))
        ncSlider.isContinuous = true
        ncSlider.numberOfTickMarks = 21
        ncSlider.allowsTickMarkValuesOnly = true
        ncSlider.widthAnchor.constraint(equalToConstant: 250).isActive = true
        
        let sliderLabels = NSStackView()
        sliderLabels.orientation = .horizontal
        sliderLabels.widthAnchor.constraint(equalToConstant: 250).isActive = true
        let lblMin = NSTextField(labelWithString: L10n.text("noiseCancellingShort"))
        lblMin.font = NSFont.systemFont(ofSize: 9)
        lblMin.textColor = .secondaryLabelColor
        let lblMax = NSTextField(labelWithString: "20")
        lblMax.font = NSFont.systemFont(ofSize: 9)
        lblMax.textColor = .secondaryLabelColor
        let spacerLabels = NSView()
        spacerLabels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sliderLabels.addArrangedSubview(lblMin)
        sliderLabels.addArrangedSubview(spacerLabels)
        sliderLabels.addArrangedSubview(lblMax)
        
        sliderContainer.addArrangedSubview(ncStatusLabel)
        sliderContainer.addArrangedSubview(ncSlider)
        sliderContainer.addArrangedSubview(sliderLabels)
        
        mainStack.addArrangedSubview(sliderContainer)
        
        // Sese Odaklan (Voice Focus)
        voiceFocusCheckbox = NSButton(checkboxWithTitle: L10n.text("voiceFocus"), target: self, action: #selector(onVFToggled(_:)))
        voiceFocusCheckbox.font = NSFont.systemFont(ofSize: 11)
        mainStack.addArrangedSubview(voiceFocusCheckbox)
        
        mainStack.addArrangedSubview(makeDivider())
        
        // ==========================================
        // 4. EKOLAYZIR (EQ) & CLEAR BASS
        // ==========================================
        let eqHeaderStack = NSStackView()
        eqHeaderStack.orientation = .horizontal
        eqHeaderStack.alignment = .centerY
        eqHeaderStack.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        let eqTitle = NSTextField(labelWithString: L10n.text("equalizer"))
        eqTitle.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        
        eqPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        eqPopup.addItem(withTitle: L10n.text("bassBoost"))
        eqPopup.lastItem?.tag = EQPreset.bassBoost.rawValue
        eqPopup.addItem(withTitle: L10n.text("excited"))
        eqPopup.lastItem?.tag = EQPreset.excited.rawValue
        eqPopup.addItem(withTitle: L10n.text("vocal"))
        eqPopup.lastItem?.tag = EQPreset.vocal.rawValue
        eqPopup.addItem(withTitle: L10n.text("trebleBoost"))
        eqPopup.lastItem?.tag = EQPreset.trebleBoost.rawValue
        eqPopup.addItem(withTitle: L10n.text("off"))
        eqPopup.lastItem?.tag = EQPreset.off.rawValue
        eqPopup.target = self
        eqPopup.action = #selector(onEQChanged(_:))
        
        let spacerEQ = NSView()
        spacerEQ.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        eqHeaderStack.addArrangedSubview(eqTitle)
        eqHeaderStack.addArrangedSubview(spacerEQ)
        eqHeaderStack.addArrangedSubview(eqPopup)
        mainStack.addArrangedSubview(eqHeaderStack)
        
        // Clear Bass Box
        let cbBox = NSStackView()
        cbBox.orientation = .vertical
        cbBox.alignment = .leading
        cbBox.spacing = 4
        cbBox.wantsLayer = true
        cbBox.layer?.cornerRadius = 8
        cbBox.layer?.backgroundColor = panelBackgroundColor().cgColor
        cbBox.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        cbBox.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        cbStatusLabel = NSTextField(labelWithString: "\(L10n.text("clearBass")): +0")
        cbStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        cbStatusLabel.textColor = .systemOrange
        
        cbSlider = NSSlider(value: 0, minValue: -10, maxValue: 10, target: self, action: #selector(onCBSliderMoved(_:)))
        cbSlider.isContinuous = true
        cbSlider.numberOfTickMarks = 21
        cbSlider.allowsTickMarkValuesOnly = true
        cbSlider.widthAnchor.constraint(equalToConstant: 250).isActive = true
        
        cbBox.addArrangedSubview(cbStatusLabel)
        cbBox.addArrangedSubview(cbSlider)
        mainStack.addArrangedSubview(cbBox)
        
        mainStack.addArrangedSubview(makeDivider())
        
        // ==========================================
        // 5. FOOTER (Çıkış)
        // ==========================================
        let footerStack = NSStackView()
        footerStack.orientation = .horizontal
        footerStack.widthAnchor.constraint(equalToConstant: 274).isActive = true
        
        let quitBtn = NSButton(title: L10n.text("quit"), target: self, action: #selector(onQuit))
        quitBtn.isBordered = false
        quitBtn.font = NSFont.systemFont(ofSize: 11)
        quitBtn.contentTintColor = .secondaryLabelColor
        
        footerStack.addArrangedSubview(quitBtn)
        mainStack.addArrangedSubview(footerStack)
    }
    
    func makeBatteryCard(title: String, imageName: String) -> (NSView, NSTextField) {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .centerX
        card.spacing = 3
        card.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        card.wantsLayer = true
        card.layer?.cornerRadius = 6
        card.layer?.backgroundColor = panelBackgroundColor().cgColor
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center

        let iconView = NSImageView()
        iconView.image = ImageLoader.image(named: imageName, size: NSSize(width: 34, height: 34))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant: 34).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 34).isActive = true
        
        let valueLabel = NSTextField(labelWithString: "%--")
        valueLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        valueLabel.alignment = .center
        
        card.addArrangedSubview(titleLabel)
        card.addArrangedSubview(iconView)
        card.addArrangedSubview(valueLabel)
        return (card, valueLabel)
    }

    private func panelBackgroundColor() -> NSColor {
        let isDarkMode = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkMode
            ? NSColor(calibratedWhite: 0.16, alpha: 0.82)
            : NSColor(calibratedWhite: 1.0, alpha: 0.42)
    }
    
    func makeDivider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 274).isActive = true
        return box
    }
    
    func syncUI(with state: HeadphoneState) {
        guard isViewLoaded else { return }
        
        let isConnected = state.isConnected
        bt.logDebug("syncUI called: isConnected=\(isConnected), ncMode=\(state.ncMode), masterSwitchCurrentState=\(masterSwitch.state == .on ? "ON" : "OFF")")
        if isConnected {
            statusTextLabel.stringValue = L10n.text("connected")
        } else if bt.isConnecting {
            statusTextLabel.stringValue = L10n.text("connecting")
        } else {
            statusTextLabel.stringValue = L10n.text("disconnected")
        }
        
        if isConnected {
            leftBatLabel.stringValue = "%\(state.leftBattery)\(state.leftCharging ? " ⚡" : "")"
            rightBatLabel.stringValue = "%\(state.rightBattery)\(state.rightCharging ? " ⚡" : "")"
            caseBatLabel.stringValue = "%\(state.caseBattery)\(state.caseCharging ? " ⚡" : "")"
        } else {
            leftBatLabel.stringValue = "%--"
            rightBatLabel.stringValue = "%--"
            caseBatLabel.stringValue = "%--"
        }
        
        let isControlOn = (state.ncMode != .off)
        masterSwitch.state = isControlOn ? .on : .off
        masterSwitch.isEnabled = isConnected
        
        ncSlider.isEnabled = isConnected && isControlOn
        
        if !isControlOn {
            ncStatusLabel.stringValue = "\(L10n.text("off")) (\(L10n.text("passiveIsolation")))"
            ncStatusLabel.textColor = .secondaryLabelColor
            voiceFocusCheckbox.isEnabled = false
            voiceFocusCheckbox.state = state.voiceFocus ? .on : .off
        } else if state.ncMode == .anc {
            if ncDebounceTimer == nil {
                ncSlider.doubleValue = 0
                ncStatusLabel.stringValue = L10n.text("noiseCancelling")
                ncStatusLabel.textColor = .systemBlue
                voiceFocusCheckbox.isEnabled = false
                voiceFocusCheckbox.state = .off
            }
        } else if state.ncMode == .ambient {
            if ncDebounceTimer == nil {
                ncSlider.doubleValue = Double(state.ambientLevel)
                ncStatusLabel.stringValue = "\(L10n.text("ambientSound")): \(L10n.text("level")) \(state.ambientLevel)"
                ncStatusLabel.textColor = .systemPurple
                voiceFocusCheckbox.isEnabled = isConnected
                voiceFocusCheckbox.state = state.voiceFocus ? .on : .off
            }
        }
        
        // EQ
        eqPopup.isEnabled = isConnected
        eqPopup.selectItem(withTag: state.currentPreset.rawValue)
        
        // Clear Bass
        cbSlider.isEnabled = isConnected
        if cbDebounceTimer == nil {
            cbSlider.doubleValue = Double(state.clearBass)
            let cbText = state.clearBass > 0 ? "+\(state.clearBass)" : "\(state.clearBass)"
            cbStatusLabel.stringValue = "Clear Bass: \(cbText)"
        }
    }
    
    // ==========================================
    // ACTION HANDLERS
    // ==========================================
    
    @objc func onRefresh() {
        bt.logDebug("onRefresh clicked")
        bt.refreshStatus()
    }
    
    @objc func onMasterToggled(_ sender: NSSwitch) {
        bt.logDebug("onMasterToggled clicked: sender.state=\(sender.state == .on ? "ON" : "OFF"), sliderVal=\(ncSlider.doubleValue)")
        if sender.state == .off {
            bt.setNoiseMode(.off)
        } else {
            let val = Int(round(ncSlider.doubleValue))
            if val == 0 {
                bt.setNoiseMode(.anc)
            } else {
                bt.setNoiseMode(.ambient, ambientLevel: UInt8(val), voiceFocus: voiceFocusCheckbox.state == .on)
            }
        }
    }
    
    @objc func onNCSliderMoved(_ sender: NSSlider) {
        let val = Int(round(sender.doubleValue))
        
        if val == 0 {
            ncStatusLabel.stringValue = L10n.text("noiseCancelling")
            ncStatusLabel.textColor = .systemBlue
            voiceFocusCheckbox.isEnabled = false
            voiceFocusCheckbox.state = .off
        } else {
            ncStatusLabel.stringValue = "\(L10n.text("ambientSound")): \(L10n.text("level")) \(val)"
            ncStatusLabel.textColor = .systemPurple
            voiceFocusCheckbox.isEnabled = true
        }
        
        ncDebounceTimer?.invalidate()
        ncDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.ncDebounceTimer = nil
            if val == 0 {
                self.bt.setNoiseMode(.anc)
            } else {
                let vf = (self.voiceFocusCheckbox.state == .on)
                self.bt.setNoiseMode(.ambient, ambientLevel: UInt8(val), voiceFocus: vf)
            }
        }
    }
    
    @objc func onVFToggled(_ sender: NSButton) {
        let isVF = (sender.state == .on)
        let val = max(UInt8(round(ncSlider.doubleValue)), 1)
        bt.setNoiseMode(.ambient, ambientLevel: val, voiceFocus: isVF)
    }
    
    @objc func onEQChanged(_ sender: NSPopUpButton) {
        if let tag = sender.selectedItem?.tag, let preset = EQPreset(rawValue: tag) {
            bt.setEqualizer(preset)
        }
    }
    
    @objc func onCBSliderMoved(_ sender: NSSlider) {
        let val = Int(round(sender.doubleValue))
        let cbText = val > 0 ? "+\(val)" : "\(val)"
        cbStatusLabel.stringValue = "Clear Bass: \(cbText)"
        
        cbDebounceTimer?.invalidate()
        cbDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.cbDebounceTimer = nil
            self.bt.setClearBass(val)
        }
    }
    
    @objc func onQuit() {
        NSApplication.shared.terminate(nil)
    }
}
