module Redcar
  class ApplicationSWT
    class Notebook
      class TabDragAndDropListener
        include org.eclipse.swt.dnd.DragSourceListener
        include org.eclipse.swt.dnd.DropTargetListener
                
        # A TabPaintListener allows clients to draw 
        # indicators next to a tab in the tab folder
        class TabPaintListener
          include org.eclipse.swt.events.PaintListener    
          attr_writer :item
      
          def paintControl(event)
            if @item && @item.bounds
              bounds = @item.bounds
              side_length = bounds.height / 3
              triangle = [bounds.x + 2, bounds.y + side_length,
                bounds.x + side_length + 2, bounds.y,
                bounds.x - side_length + 2, bounds.y]
              event.gc.background = ApplicationSWT.display.system_color Swt::SWT::COLOR_DARK_GRAY
              event.gc.fill_polygon(triangle.to_java(:int))
            end
          end
        end

        def initialize(notebook)
          @notebook = notebook
          @paint_listener = TabPaintListener.new
        end
        
        def tab_folder
          @notebook.tab_folder
        end
        
        # DragSourceListener interface implementation
        # When a drag starts, the dragged tab is marked
        def dragStart(event)
          @dragged_tab_controller = @notebook.tab_widget_to_tab_model(tab_folder.selection).controller
          @dragged_tab_controller.dragging = true
        end
        
        # DragSourceListener interface implementation
        # When a drag finishes, the dragged tab is unmarked and released
        def dragFinished(event)
          @dragged_tab_controller.dragging = false
          @dragged_tab_controller = @paint_listener.item = nil
          tab_folder.redraw
        end
        
        # DropTargetListener interface implementation
        # A @link{TabPaintListener} is added to the tab folder when dragging into it
        # to indicate where the drop would happen
        def dragEnter(event)
          tab_folder.add_paint_listener(@paint_listener)
        end
        
        # DropTargetListener interface implementation
        # If a drag leaves the tab folder, remove the @link{TabPaintListener}
        def dragLeave(event)
          tab_folder.remove_paint_listener(@paint_listener)
          tab_folder.redraw
        end

        # DropTargetListener interface implementation
        # While dragging, update the @link{TabPaintListener} to show drop indicators
        def dragOver(event)
          @paint_listener.item = event_to_tab_widget(event)
          tab_folder.redraw
        end

        # DropTargetListener interface implementation
        # Drop the dragged tab on the notebook at the target position
        def drop(event)
          target_tab_widget = event_to_tab_widget(event)
          unless @dragged_tab_controller && target_tab_widget == @dragged_tab_controller.item
            dragged_tab_model = @dragged_tab_controller.model if @dragged_tab_controller
            dragged_tab_model ||= Redcar.app.all_tabs.detect {|t| t.controller.dragging?}
            @notebook.model.grab_tab_from(dragged_tab_model.notebook, dragged_tab_model)
            move_behind(dragged_tab_model.controller, target_tab_widget)
          end
        end

        # Move the tab controlled by the given controller in behind the indicated tab
        # @param [Redcar::ApplicationSWT::Tab] the dragged tab's controller
        # @param [SWT::Custom::CTabItem] the item to drop behind
        def move_behind(tab_controller, tab_widget)
          position = (tab_folder.index_of(tab_widget) if tab_widget) || 0
          tab_controller.move_tab_widget_to_position(position)
        end
        
        # Find the CTabItem targeted by a given event        
        def event_to_tab_widget(event)
          if tab_folder.item_count > 0          
            tab_folder.item(tab_folder.to_control(event.x, event.y)) or 
            tab_folder.items[tab_folder.item_count - 1]
          end
        end

        # Unimplemented interface methods
        def dragSetData(event); end
        def dragOperationChanged(event); end
        def dropAccept(event); end
      end
    end
  end
end

