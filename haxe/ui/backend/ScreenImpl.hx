package haxe.ui.backend;

import h2d.Object;
import h2d.Scene;
import haxe.ui.Toolkit;
import haxe.ui.backend.heaps.EventMapper;
import haxe.ui.backend.heaps.MouseHelper;
import haxe.ui.backend.heaps.ScreenUtils;
import haxe.ui.core.Component;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import hxd.Window;

class ScreenImpl extends ScreenBase {
    private var _mapping:Map<String, UIEvent->Void>;

    public function new() {
        _mapping = new Map<String, UIEvent->Void>();
        addResizeListener();
    }
    
    private var _resizeListenerAdded:Bool = false;
    private function addResizeListener() {
        if (_resizeListenerAdded == true) {
            return;
        }
        
        _resizeListenerAdded = true;
        if (Window.getInstance() != null) {
            Window.getInstance().addResizeEvent(onWindowResize);
        }
    }
    
    private var _updateCallbackAdded:Bool = false;
    private function addUpdateCallback() {
        if (_updateCallbackAdded == true) {
            return;
        }
        
        if (options == null || options.manualUpdate == null || options.manualUpdate == false) {
            _updateCallbackAdded = true;
            MainLoop.add(BackendImpl.update);
        }
    }
    
    private function onWindowResize() {
        resizeRootComponents();
    }
    
    private var _root:Object = null;
    public var root(get, set):Object;
    private function get_root():Object {
        if (_root != null) {
            return _root;
        }
        
        if (options == null) {
            return null;
        }
        return options.root;
    }
    private function set_root(value:Object):Object {
        _root = value;
        return value;
    }

    public var scene(get, null):Scene;
    private function get_scene():Scene {
        if (root == null) {
            return null;
        }
        return root.getScene();
    }
    
    
    private override function set_options(value:ToolkitOptions):ToolkitOptions {
        super.set_options(value);
        addUpdateCallback();
        return value;
    }
    
    private override function get_width():Float {
        return Window.getInstance().width / Toolkit.scaleX;
    }

    private override function get_height():Float {
        return Window.getInstance().height / Toolkit.scaleY;
    }

    private override function get_dpi():Float {
        return ScreenUtils.dpi;
    }

    private override function get_isRetina():Bool {
        return ScreenUtils.isRetinaDisplay();
    }
    
    private var cursorLocked:Bool = false;
    public function setCursor(cursor:String, lock=false) {
        if (cursorLocked) {
            return;
        }
        cursorLocked = lock;

        if (cursor == "pointer") {
            hxd.System.setNativeCursor(Button);
        } else if (cursor == "text") {
            hxd.System.setNativeCursor(TextInput);
        } else if (cursor == "col-resize") {
            hxd.System.setNativeCursor(Move);
        } else if (cursor == "row-resize") {
            hxd.System.setNativeCursor(Move);
        }else {
            hxd.System.setNativeCursor(Default);
        }
    }
    
    public function lockCursor() {
        cursorLocked = true;
    }
    public function unlockCursor() {
        cursorLocked = false;
    }
    
    public override function addComponent(component:Component):Component {
        rootComponents.push(component);
        if (component.parent == null || component.parent == root) {
            if (_removedComponents.indexOf(component) != -1) {
                if (root == null) {
                    trace("WARNING: trying to add a component to a null root. Either set Screen.instance.root or specify one in Toolkit.init");
                    return component;
                }
                _removedComponents.remove(component);
                //rootScene.addChildAt(component, 0);
                component.visible = true;
            } else {
                if (root == null) {
                    trace("WARNING: trying to add a component to a null root. Either set Screen.instance.root or specify one in Toolkit.init");
                    return component;
                }
                root.addChild(component);
            }
        }
        resizeComponent(component);
        return component;
    }

    private var _removedComponents:Array<Component> = []; // TODO: probably ill conceived
    public override function removeComponent(component:Component, dispose:Bool = true):Component {
        rootComponents.remove(component);
        if (_removedComponents.indexOf(component) == -1) {
            if (root == null) {
                trace("WARNING: trying to remove a component to a null root. Either set Screen.instance.root or specify one in Toolkit.init");
                return component;
            }
            //rootScene.removeChild(component);
            _removedComponents.push(component);
            component.visible = false;
            if (dispose == true && root != null) {
                root.removeChild(component);
            }
            
            if (@:privateAccess component.inBounds(MouseHelper.currentMouseX, MouseHelper.currentMouseY)) {
                setCursor(null);
            }
        }
        return component;
    }

    private override function handleSetComponentIndex(component:Component, index:Int) {
        if (root == null) {
            trace("WARNING: trying to set a component index in a null root. Either set Screen.instance.root or specify one in Toolkit.init");
            return;
        }
        root.addChildAt(component, index);
        resizeComponent(component);
    }
    
    //***********************************************************************************************************
    // Events
    //***********************************************************************************************************
    private override function supportsEvent(type:String):Bool {
        return EventMapper.HAXEUI_TO_HEAPS.get(type) != null;
    }

    private override function mapEvent(type:String, listener:UIEvent->Void) {
        switch (type) {
            case MouseEvent.MOUSE_MOVE:
                if (_mapping.exists(type) == false) {
                    _mapping.set(type, listener);
                    MouseHelper.notify(MouseEvent.MOUSE_MOVE, __onMouseMove);
                }
                
            case MouseEvent.MOUSE_DOWN:
                if (_mapping.exists(type) == false) {
                    _mapping.set(type, listener);
                    MouseHelper.notify(MouseEvent.MOUSE_DOWN, __onMouseDown);
                }
                
            case MouseEvent.MOUSE_UP:
                if (_mapping.exists(type) == false) {
                    _mapping.set(type, listener);
                    MouseHelper.notify(MouseEvent.MOUSE_UP, __onMouseUp);
                }
        }
    }
    
    private function __onMouseMove(event:MouseEvent) {
        var fn = _mapping.get(MouseEvent.MOUSE_MOVE);
        if (fn != null) {
            var mouseEvent = new MouseEvent(MouseEvent.MOUSE_MOVE);
            mouseEvent.screenX = event.screenX;
            mouseEvent.screenY = event.screenY;
            mouseEvent.buttonDown = event.data;
            fn(mouseEvent);
        }
    }
    
    private function __onMouseDown(event:MouseEvent) {
        var fn = _mapping.get(MouseEvent.MOUSE_DOWN);
        if (fn != null) {
            var mouseEvent = new MouseEvent(MouseEvent.MOUSE_DOWN);
            mouseEvent.screenX = event.screenX;
            mouseEvent.screenY = event.screenY;
            mouseEvent.buttonDown = event.data;
            fn(mouseEvent);
        }
    }
    
    private function __onMouseUp(event:MouseEvent) {
        var fn = _mapping.get(MouseEvent.MOUSE_UP);
        if (fn != null) {
            var mouseEvent = new MouseEvent(MouseEvent.MOUSE_UP);
            mouseEvent.screenX = event.screenX;
            mouseEvent.screenY = event.screenY;
            mouseEvent.buttonDown = event.data;
            fn(mouseEvent);
        }
    }
}