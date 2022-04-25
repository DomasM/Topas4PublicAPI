classdef MATLABExample_NET_SDK
    properties
        topas = [];
    end

    methods
        function self = MATLABExample_NET_SDK()
            serialNumber = "00666"; %enter serial number or your own device here
            NET.addAssembly(fullfile(fileparts(mfilename('fullpath')), '..\..\NET_SDK\Topas4Lib.dll')); %this is a reference to Topas4Lib.dll, which is located two directories up
            TopasDevice = Topas4Lib.TopasDevice;
            self.topas = TopasDevice.FindTopasDevice(serialNumber);
            if isempty(self.topas)
                fprintf('Device with serial number %s not found\n', serialNumber)
            end
            self.run();
        end

        function run(self)
          if isempty(self.topas)
            return
          end
          self.getCalibrationInfoAndSetWavelength()
          pause(0.2)
          self.changeShutter()

          availableMotors = self.topas.MotorsService.GetAllProperties().Motors;
          if(availableMotors.Count > 0)
            self.tweakMotorPositions(Item(availableMotors,0))
          end
        end

        function getCalibrationInfoAndSetWavelength(self)
           %Get basic calibration info and set random wavelength using random interaction%
           interactions = self.topas.WavelengthService.GetExpandedInteractions();
           disp("Available interactions:")
           for i = 0:interactions.Count-1
               item = Item(interactions,i);
               fprintf("%s %d - %d nm\n", item.Type, item.OutputRange.From, item.OutputRange.To)
           end
           if interactions.Count > 0
              interaction = Item(interactions, randi(interactions.Count, 1)-1); %set wavelength using random interaction
              %wavelength is selected randomly too, to be in valid range for that
                                                                                            %interaction
              wavelengthToSet = interaction.OutputRange.From + interaction.OutputRange.Diff * rand(1);
              fprintf("setting wavelength %.4f nm using interaction %s\n", wavelengthToSet, interaction.Type)
              self.topas.SetWavelength(wavelengthToSet, interaction.Type)
              %if I don't care about interaction used:
              %self.topas.WavelengthService.SetOutputAnyInteraction
              self.waitTillWavelengthIsSet()
           else
              disp("There are no calibrated interactions")
           end
        end


        function changeShutter(self)
            isShutterOpen = self.topas.ShutterService.GetIsShutterOpen();
            if isShutterOpen
                shutterCommandStr = "close";
            else
                shutterCommandStr = "open";
            end
            line = upper(input("Do you want to " + shutterCommandStr + " shutter? (Y/N): ", "s"));
            if line == "Y" || line == "YES"
               self.topas.ShutterService.SetOpenCloseShutter(~isShutterOpen) 
            end
        end
    
        function waitTillWavelengthIsSet(self)
           % Waits till wavelength setting is finished.  If user needs to do any manual
           % operations (e.g.  change wavelength separator), inform him/her and wait for confirmation.
           while true
                s = self.topas.WavelengthService.GetOutput();
                fprintf("%d %% done\n", s.WavelengthSettingCompletionPart * 100.0)
                if ~s.IsWavelengthSettingInProgress || s.IsWaitingForUserAction
                    break
                end
           end
           state = self.topas.WavelengthService.GetOutput();
           if state.IsWaitingForUserAction
              disp("User actions required. Press enter key to confirm.")
              %inform user what needs to be done
              for i = 0:state.Messages.Count-1
                  item = Item(state.Messages, i);
                 if isempty(item.Image)
                     imageNameStr = "";
                 else
                     imageNameStr = "image name: " + item.Image;
                 end
                  disp([item.Text, " , ", imageNameStr]);
              end
              input('');%wait for user confirmation
              options = Mint.Services.FinishSettingWavelengthOptions();
              options.RestoreShutter = true;
              % tell the device that required actions have been performed.  If
              % shutter was open before setting wavelength it will be opened again
              self.topas.WavelengthService.FinishWavelengthSettingAfterUserActions(options);
           end
           disp("Done setting wavelength")
        end


        function tweakMotorPositions(self, motor)
            %Shows how to move single motor to desired position and read current position
            f = figure('numbertitle', 'off', 'name', 'Press a key','keypressfcn',@keypressfcn,'windowstyle', 'modal','Units', 'Normalized','position', [0.5 0.5 0.21 0.05]) ;
            annotation('textbox', 'Position', [0,0,1,1], 'String', {"Press Up/Down arrow keys to move motor " + string(motor.Title) + ". ", "Press Escape to finish motor position tweaking."})
            uiwait(f);
        
            function keypressfcn(~,evt)
                switch evt.Key
                    case 'escape' %ESC
                        close(f);
                    case 'uparrow' %Up arrow
                        current = self.topas.MotorsService.GetMotor(motor.Index).TargetPosition;
                        self.topas.MotorsService.SetTargetPosition(motor.Index, current + 8)
                        %steps, if you want to use units use
                        %SetMotorTargetPositionInUnits
                    case 'downarrow' %Down arrow
                        self.topas.MotorsService.SetTargetPositionRelative(motor.Index, -8)
                        %equivalent functionality to UpArrow
                    otherwise
                    disp("Invalid key. Use Escape to stop motor position adjustment, Up and Down arrows to move motor.")
                end
            end
        end
    end
end