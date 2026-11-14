import SwiftUI

struct HomeArrangementView:View {
    @ObservedObject var engine:GameEngine
    let plot:CityPlot
    var area:HomeArea = .room
    @State private var selected:InteriorItem?
    @State private var dragStart:RoomPlacement?
    @State private var draft:RoomPlacement?
    @State private var snapToGrid = true
    @State private var history = HomeArrangementHistory()
    @State private var notice = "Select a furniture set, then drag it or use the movement buttons. Changes save immediately."
    private var housing:CityHousing { engine.economy.housing ?? CityHousing() }
    private var items:Set<InteriorItem> { housing.items(in:plot) }
    private var layout:[InteriorItem:RoomPlacement] { housing.layout(in:plot) }
    private var furniture:[InteriorItem] { InteriorItem.allCases.filter { items.contains($0) && $0.movable && $0.area == area } }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text(area == .room ? "Arrange your room":"Arrange your terrace").font(.title2.bold())
                Text(HomeRoomGeometry.dimensionsLabel).font(.subheadline.monospacedDigit()).accessibilityIdentifier("Home room dimensions")
                Text("Move and rotate furnishings for \(plot.name). Keep the entrance clear. Paintings slide along the left gallery wall; pendant lights can hang above floor furniture.").font(.subheadline).foregroundStyle(.white)
                HStack {
                    Button("Undo",systemImage:"arrow.uturn.backward") { restore(undo:true) }.flightButtonGlass()
                        .disabled(history.undoTarget == nil).accessibilityIdentifier("Undo furniture edit")
                    Button("Redo",systemImage:"arrow.uturn.forward") { restore(undo:false) }.flightButtonGlass()
                        .disabled(history.redoTarget == nil).accessibilityIdentifier("Redo furniture edit")
                }.buttonStyle(GlowingFlightButton())
                Toggle("Snap to half-metre grid",isOn:$snapToGrid).flightButtonGlass().accessibilityIdentifier("Furniture grid snapping")
                floorPlan.frame(height:320)
                Text(placementFeedback).font(.caption).foregroundStyle(.white).accessibilityIdentifier("Arrangement notice")
                Text("Grid lines are 2 m apart. Numbers match the furniture list below.").font(.caption2).foregroundStyle(.white)
                ForEach(furniture) { item in
                    Button { selected = item; draft = nil } label: {
                        HStack { Text("\(item.index+1). \(item.name)"); Spacer(); if selected == item { Image(systemName:"checkmark.circle.fill") } }
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Select furniture " + item.id)
                }
                if let selected,items.contains(selected) {
                    Text(selected.name).font(.headline)
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                        Button("Left") { nudge(selected,[-0.5,0]) }.flightButtonGlass().disabled(selected.layer == .wall).accessibilityIdentifier("Move furniture left")
                        Button("Right") { nudge(selected,[0.5,0]) }.flightButtonGlass().disabled(selected.layer == .wall).accessibilityIdentifier("Move furniture right")
                        Button("Towards window") { nudge(selected,[0,-0.5]) }.flightButtonGlass().accessibilityIdentifier("Move furniture forward")
                        Button("Towards door") { nudge(selected,[0,0.5]) }.flightButtonGlass().accessibilityIdentifier("Move furniture backward")
                    }.buttonStyle(GlowingFlightButton())
                    Button("Rotate 90°") {
                        var p = HomeRoomLayout.placement(selected,in:layout); p.turns = (p.turns+1)%4; save(selected,p)
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton()).disabled(!selected.canRotate).accessibilityIdentifier("Rotate furniture")
                    let placement = HomeRoomLayout.placement(selected,in:layout)
                    Text(String(format:"Position %.1f, %.1f · rotation %d°",placement.x,placement.z,placement.turns*90))
                        .font(.caption.monospacedDigit()).accessibilityIdentifier("Furniture placement")
                }
                if furniture.isEmpty { Text("Install furnishings for this area from the Emporium first.").font(.subheadline) }
                Button("Reset furniture positions") {
                    let before = layout
                    engine.resetResidenceLayout(plot,area:area)
                    history.record(before:before,after:layout); draft = nil; notice = "Original positions restored · saved. Undo is available."
                }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Reset home layout")
                CityHomePreview(plot:plot,interior:true,items:items,layout:layout,states:housing.states(in:plot),area:area).frame(height:260)
            }.padding(20).frame(maxWidth:820).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("Arrange " + area.name.lowercased()).navigationBarTitleDisplayMode(.inline)
            .onAppear { if selected == nil { selected = furniture.first } }
    }
    private var floorPlan:some View {
        GeometryReader { proxy in
            let roomWidth = CGFloat(HomeRoomGeometry.width), roomDepth = CGFloat(HomeRoomGeometry.depth)
            let scale = min((proxy.size.width-24)/roomWidth,(proxy.size.height-24)/roomDepth)
            let origin = CGPoint(x:proxy.size.width/2,y:proxy.size.height/2)
            ZStack {
                RoundedRectangle(cornerRadius:14).fill(.black.opacity(0.35))
                Rectangle().stroke(.white.opacity(0.4),lineWidth:2).frame(width:scale*roomWidth,height:scale*roomDepth).position(origin)
                Canvas { context,size in
                    var grid = Path()
                    for x in stride(from:CGFloat(0),through:roomWidth,by:2) {
                        grid.move(to:CGPoint(x:x*scale,y:0)); grid.addLine(to:CGPoint(x:x*scale,y:size.height))
                    }
                    for z in stride(from:CGFloat(0),through:roomDepth,by:2) {
                        grid.move(to:CGPoint(x:0,y:z*scale)); grid.addLine(to:CGPoint(x:size.width,y:z*scale))
                    }
                    context.stroke(grid,with:.color(.white.opacity(0.1)),lineWidth:0.5)
                }.frame(width:roomWidth*scale,height:roomDepth*scale).position(origin).allowsHitTesting(false)
                Text(area == .room ? "WINDOW":"SKYLINE").font(.caption2).foregroundStyle(.white).position(x:origin.x,y:origin.y-scale*(roomDepth/2-0.8))
                let entrance = HomeRoomGeometry.entrance, clear = HomeRoomGeometry.entranceHalfSize
                Rectangle().fill(.orange.opacity(0.15)).frame(width:CGFloat(clear.x*2)*scale,height:CGFloat(clear.y*2)*scale)
                    .position(x:origin.x+CGFloat(entrance.x)*scale,y:origin.y+CGFloat(entrance.y)*scale)
                Text("DOOR · KEEP CLEAR").font(.system(size:8)).foregroundStyle(.white)
                    .position(x:origin.x+CGFloat(entrance.x)*scale,y:origin.y+scale*(roomDepth/2-0.5))
                ForEach(furniture) { item in
                    furnitureTile(item,origin:origin,scale:scale)
                }
            }
        }.accessibilityIdentifier("Home furniture floor plan")
    }
    private func furnitureTile(_ item:InteriorItem,origin:CGPoint,scale:CGFloat) -> some View {
        let stored = HomeRoomLayout.placement(item,in:layout)
        let placement = selected == item ? draft ?? stored:stored
        let half = placement.halfSize(for:item)
        let valid = HomeRoomLayout.canPlace(item,at:placement,items:items,layout:layout)
        let fill:Color = selected == item ? (valid ? FlightStyle.mint.opacity(0.8):Color.red.opacity(0.7)):Color.blue.opacity(0.45)
        let width = max(4,CGFloat(half.x)*scale*2), height = max(4,CGFloat(half.y)*scale*2)
        let x = origin.x+CGFloat(placement.x)*scale, y = origin.y+CGFloat(placement.z)*scale
        return Text(width>44 && height>24 ? item.name:String(item.index+1)).font(.system(size:9,weight:.semibold)).multilineTextAlignment(.center).lineLimit(3)
            .frame(width:width,height:height)
            .background(fill,in:RoundedRectangle(cornerRadius:4))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius:4).stroke(selected == item ? Color.white:Color.clear,lineWidth:2))
            .position(x:x,y:y)
            .onTapGesture { selected = item; draft = nil }
            .gesture(DragGesture(minimumDistance:3).onChanged { value in
                if dragStart == nil { selected = item; dragStart = stored }
                guard let start = dragStart else { return }
                let candidate = RoomPlacement(x:start.x+Float(value.translation.width/scale),z:start.z+Float(value.translation.height/scale),turns:start.turns)
                draft = item.placing(candidate,snap:snapToGrid)
            }.onEnded { _ in
                if let draft { save(item,draft) }
                dragStart = nil; draft = nil
            })
            .accessibilityLabel(item.name).accessibilityIdentifier("Furniture floor plan " + item.id)
    }
    private var placementFeedback:String {
        guard let selected,let draft else { return notice }
        return HomeRoomLayout.placementIssue(selected,at:draft,items:items,layout:layout) ?? "Release to place here."
    }
    private func nudge(_ item:InteriorItem,_ delta:SIMD2<Float>) {
        var p = HomeRoomLayout.placement(item,in:layout); p.x += delta.x; p.z += delta.y; save(item,item.placing(p,snap:false))
    }
    private func save(_ item:InteriorItem,_ placement:RoomPlacement) {
        let before = layout
        if engine.placeResidenceItem(item,in:plot,at:placement) {
            history.record(before:before,after:layout); notice = "Position saved for this house"
        } else {
            notice = HomeRoomLayout.placementIssue(item,at:placement,items:items,layout:layout) ?? "The room has changed. Choose another position."
        }
    }
    private func restore(undo:Bool) {
        guard let target = undo ? history.undoTarget:history.redoTarget else { return }
        let current = layout
        guard engine.restoreResidenceLayout(target,in:plot) else {
            notice = "The furnishings have changed. Start a new edit before using Undo."; history = HomeArrangementHistory(); return
        }
        if undo { history.didUndo(current:current) } else { history.didRedo(current:current) }
        draft = nil; dragStart = nil; notice = undo ? "Edit undone · saved":"Edit redone · saved"
    }
}
