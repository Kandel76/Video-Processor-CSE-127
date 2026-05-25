import gdsfactory as gf
import gdsfactory.get_netlist as get_netlist
import fractions
from gdsfactory.typings import ComponentSpec, Size, LayerSpec

import gf180mcu


@gf.cell
def nwell_psub_photodiode(width: int = 5, nplus_contact_distacne_from_top_of_nwell=0.11, nplus_contact_additional_offset_from_left=0.2):
    """Defines a nwell p-substrate photo diode

    Args:
        width: The width and height of the photo diode in microns
    """
    # corresponds to 8um in gf180mcu
    photo_diode_rect = gf.Component()
    photo_diode_nwell = gf.components.rectangle(
        size=(width, width),
        layer=gf180mcu.LAYER.nwell)

    photo_diode_rect << photo_diode_nwell

    rinner = 100
    router = 100
    n = 300  # points in circle
    # Round corners for all layers.
    photo_diode_rounded = gf.Component()
    for layer, polygons in photo_diode_rect.get_polygons().items():
        for p in polygons:
            # p_round = p.round_corners(rinner, router, n)
            photo_diode_rounded.add_polygon(p, layer=layer)

    contact_size = 0.36
    contact_layer = photo_diode_rounded.add_ref(
        gf180mcu.cells.via_stack(x_range=(0, contact_size), y_range=(0, contact_size)))

    rounded_corner_width_and_height = gf.kcl.dbu * router
    nplus = photo_diode_rounded.add_ref(gf.components.rectangle(size=(
        0.6, contact_layer.ysize + (0.6 - contact_layer.xsize)), layer=gf180mcu.LAYER.nplus))
    nplus.dxmax = photo_diode_rounded.dxmax - rounded_corner_width_and_height + \
        nplus_contact_additional_offset_from_left
    nplus.dymax = photo_diode_rounded.dymax - \
        nplus_contact_distacne_from_top_of_nwell

    contact_layer.center = nplus.center
    photo_diode_rounded.add_ports(contact_layer.ports)

    return photo_diode_rounded


@gf.cell
def reset_transistor(photodiode_spec: ComponentSpec = nwell_psub_photodiode, reset_distance_from_photo_diode=1.0):

    reset_transistor = gf.Component()

    photodiode = gf.get_component(photodiode_spec)
    # Create reset transistor
    nfet_component = gf180mcu.cells.nfet(
        w_gate=0.37, l_gate=0.36, label=True, sd_label=['S', 'D'], g_label=["gate"], gate_con_pos="bottom").copy()
    gf.add_ports.add_ports_from_labels(component=nfet_component, port_width=0.34,
                                       port_layer=gf180mcu.LAYER.metal1, layer_label=gf180mcu.LAYER.metal1_label, port_type="electrical")

    nfet_ref = reset_transistor.add_ref(nfet_component)
    reset_transistor.add_ports(nfet_ref.ports)

    # Add patch metal to meet overlap rules on M1 to contact
    source_port_ref = nfet_component.add_ref(gf.components.rectangle(size=(
        nfet_component.ports["e1"].width, nfet_component.ports["e1"].width), layer=gf180mcu.LAYER.metal1))
    source_port_ref.center = nfet_ref.ports["e1"].center

    reset_transistor.center = photodiode.ports["e1"].center
    reset_transistor.dxmin = photodiode.dxmax + reset_distance_from_photo_diode
    reset_transistor.y = reset_transistor.y + \
        (reset_transistor.y - reset_transistor.ports["e1"].y)

    contact_min_size = 0.22
    metal1_drain_contact = reset_transistor.add_ref(gf180mcu.cells.via_stack(
        x_range=(0, contact_min_size), y_range=(0, contact_min_size)))
    metal1_drain_contact.center = reset_transistor.ports['e2'].center
    reset_transistor.ports['e2'].orientation = 90
    reset_transistor.ports['e3'].orientation = 90

    return reset_transistor


@gf.cell
def source_follower_nfet(photodiode_spec: ComponentSpec = nwell_psub_photodiode, reset_transistor_spec: ComponentSpec = reset_transistor, max_distance_from_nwell=0.4):
    source_follower_nfet = gf.Component()
    photodiode = gf.get_component(photodiode_spec)
    reset_transistor = gf.get_component(reset_transistor_spec)

    width_of_gate = 1.5
    nfet_component = gf180mcu.cells.nfet(
        w_gate=width_of_gate, l_gate=0.36, label=True, sd_label=['D', 'S'], g_label=["gate"], enable_left_diffusion_contacts=False).copy()
    gf.add_ports.add_ports_from_labels(component=nfet_component, port_width=0.34,
                                       port_layer=gf180mcu.LAYER.metal1, layer_label=gf180mcu.LAYER.metal1_label, port_type="electrical", guess_port_orientation=False, port_orientation=270)

    # # Add patch metal to meet overlap rules on M1 to contact
    source_port_ref = nfet_component.add_ref(gf.components.rectangle(size=(
        nfet_component.ports["e3"].width, nfet_component.ports["e3"].width), layer=gf180mcu.LAYER.metal1))
    source_port_ref.center = nfet_component.ports["e3"].center

    poly2poly_spacing_min_rule = 0.28
    nwell_to_nplus_spacing = 0.4
    nfet_ref = source_follower_nfet.add_ref(nfet_component)
    nfet_ref.center = reset_transistor.ports["e1"].center
    nfet_ref.ymax = reset_transistor.ymin + poly2poly_spacing_min_rule
    nfet_ref.xmin = min(max(nfet_ref.xmin - photodiode.xmax,
                        nwell_to_nplus_spacing), max_distance_from_nwell) + photodiode.xmax

    source_follower_nfet.add_ports(nfet_ref.ports)
    source_follower_nfet.rotate(180, center=source_follower_nfet.center)

    # power for the source follower transistor
    vss_connection = source_follower_nfet << gf180mcu.cells.via_stack(
        x_range=(0, 0.22), y_range=(0, width_of_gate), metal_level=2, via_size=(0.26, 0.26), via_spacing=(0.28, 0.36))
    vss_connection.center = source_follower_nfet.ports['e2'].center
    source_follower_nfet.add_port("source_follower_vss_con", center=vss_connection.center,
                                  port_type="electrical", layer=gf180mcu.LAYER.metal2, orientation=270, width=vss_connection.xsize)

    return source_follower_nfet


@gf.cell
def row_select(source_follower_spec: ComponentSpec = source_follower_nfet):

    row_select = gf.Component()

    source_follower = gf.get_component(source_follower_spec)
    # Create reset transistor
    nfet_component = gf180mcu.cells.nfet(
        w_gate=0.37, l_gate=0.36, label=True, sd_label=['S', 'D'], g_label=["gate"], enable_left_diffusion_contacts=False).copy()
    gf.add_ports.add_ports_from_labels(component=nfet_component, port_width=0.34,
                                       port_layer=gf180mcu.LAYER.metal1, layer_label=gf180mcu.LAYER.metal1_label, port_type="electrical")

    nfet_ref = row_select.add_ref(nfet_component)
    row_select.add_ports(nfet_ref.ports)

    row_select.x = row_select.x + \
        (source_follower.ports["e1"].x - row_select.ports["e1"].x) + 0.23
    row_select.y = row_select.y + \
        (source_follower.ports["e1"].y - row_select.ports["e1"].y)

    # Add metal2 contact for the output of the transistor. This is what will connect
    # to the column readout circuits.
    contact_min_size = 0.22
    reset_transistor_contact = row_select.add_ref(gf180mcu.cells.via_stack(
        x_range=(0, contact_min_size), y_range=(0, contact_min_size), metal_level=2, m_enc=0.08, via_size=(0.26, 0.26)))
    reset_transistor_contact.center = row_select.ports["e2"].center

    return row_select


@gf.cell
def row_connector(size: Size, port_name: str | None = "via_port1", x_location: float = 0.0, orientation: float = 270, layer: LayerSpec = gf180mcu.LAYER.metal1, via_spec: ComponentSpec = None):
    row_connector = gf.Component()
    via_ref = None
    wire = gf.components.rectangle(
        size, layer=layer)
    row_ref = row_connector << wire
    row_connector.add_port(name="direct_metal_contact", port_type="electrical",
                           center=row_ref.center, layer=layer, width=size[1], orientation=orientation + 90)

    if via_spec:
        via_ref = row_connector << gf.get_component(via_spec)
        via_ref.center = row_ref.center
        via_ref.x += x_location - via_ref.center[0]

        row_connector.add_port(name=port_name, port_type="electrical", center=via_ref.center,
                               layer=layer, width=via_spec.xsize, orientation=orientation)
    return row_connector


@gf.cell
def poly_metal1_single_via():
    min_contact_size = 0.22
    component = gf.Component()
    via_stack = component << gf180mcu.cells.via_stack(
        x_range=(0, min_contact_size), y_range=(0, min_contact_size))
    poly_enclosure = component << gf.components.rectangle(
        size=(0.36, 0.36), layer=gf180mcu.LAYER.poly2)

    poly_enclosure.center = via_stack.center
    return component


@gf.cell
def metal1_to_metal2_via():
    via = gf180mcu.cells.via_stack(
        x_range=(0, 0.22), y_range=(0, 0.22), via_size=(0.26, 0.26), m_enc=0.08, metal_level=2)
    return via


@gf.cell
def metal1_to_metal2_via_contact():
    via = gf180mcu.cells.via_stack(
        x_range=(0, 0.22), y_range=(0, 0.22), via_size=(0.26, 0.26), m_enc=0.08, metal_level=2)
    return via


@gf.cell
def body_contact(source_follower_spec: ComponentSpec = source_follower_nfet):
    contact = gf.Component()
    source_follower = gf.get_component(source_follower_spec)

    pplus = gf.components.rectangle(
        size=(1.5, 0.4), layer=gf180mcu.LAYER.pplus)
    pplus_ref = contact << pplus
    pplus_ref.center = source_follower.center
    pplus_ref.ymax = source_follower.ymin
    pplus_ref.xmin = source_follower.xmin

    contact << gf180mcu.cells.via_stack(
        x_range=(pplus_ref.xmin, pplus_ref.xmax), y_range=(pplus_ref.ymin, pplus_ref.ymax), via_size=(0.26, 0.26), via_spacing=(0.36, 0.36), m_enc=0.08, metal_level=2)

    contact.y -= 0.12

    contact << gf180mcu.cells.via_generator(x_range=(pplus_ref.xmin, pplus_ref.xmax), y_range=(
        pplus_ref.ymin, pplus_ref.ymax), via_layer=gf180mcu.LAYER.via2, via_spacing=(0.36, 0.36), via_size=(0.26, 0.26))

    return contact


@gf.cell
def active_pixel_3t(
        photodiode_spec: ComponentSpec = nwell_psub_photodiode,
        reset_transistor_spec: ComponentSpec = reset_transistor,
        source_follower_spec: ComponentSpec = source_follower_nfet,
        row_select_spec: ComponentSpec = row_select,
        body_contact: ComponentSpec = body_contact):

    active_pixel = gf.Component()
    photodiode = gf.get_component(photodiode_spec)
    reset_transistor = gf.get_component(reset_transistor_spec)
    source_follower_nfet = gf.get_component(source_follower_spec)
    row_select = gf.get_component(row_select_spec)
    body_contact = gf.get_component(body_contact)

    photodiode_ref = active_pixel << photodiode
    active_pixel << reset_transistor
    active_pixel << source_follower_nfet
    active_pixel << row_select
    active_pixel << body_contact

    row_metal1_spacing = 0.23
    # The width of the connections like VSS, Reset and Row Select
    row_line_metal1_width = 0.25
    min_metal2_width = 0.28
    padding = 0.25

    row_base_widths = active_pixel.xsize
    horizontal_spacing = padding*2
    # Create VSS Line
    vss_voltage_line = active_pixel << row_connector(
        size=(row_base_widths + horizontal_spacing, row_line_metal1_width), via_spec=metal1_to_metal2_via(), x_location=source_follower_nfet.ports[
            'source_follower_vss_con'].center[0] + padding)
    vss_voltage_line.ymin = photodiode.ymax - 0.065
    vss_voltage_line.x -= horizontal_spacing/2

    # Create Row Reset Line
    row_reset = active_pixel << row_connector(size=(
        row_base_widths + horizontal_spacing, row_line_metal1_width), x_location=reset_transistor.ports['e3'].center[0] + padding, via_spec=poly_metal1_single_via())
    row_reset.ymin = vss_voltage_line.ymax + row_metal1_spacing
    row_reset.x -= horizontal_spacing/2

    # Create Row Enable Line
    row_enable = active_pixel << row_connector(
        size=(row_base_widths + horizontal_spacing, row_line_metal1_width), x_location=row_select.ports['e3'].center[0] + padding, via_spec=poly_metal1_single_via(), orientation=90)
    row_enable.ymax = photodiode.ymin
    row_enable.x -= horizontal_spacing/2

    # ensure that the pixel is square.
    if (active_pixel.ysize < row_base_widths):
        row_enable.y -= row_base_widths - active_pixel.ysize

    vertical_spacing = padding * 2
    column_readout = active_pixel << gf.components.rectangle(
        size=(min_metal2_width, active_pixel.ysize + vertical_spacing), layer=gf180mcu.LAYER.metal2)
    column_readout.x = row_select.ports['e2'].center[0]
    column_readout.ymin = active_pixel.ymin - vertical_spacing/2

    # Create GND Connection and ensure tranisistors are covered from light
    ground_connection_light_blocker_ref1 = active_pixel << gf.components.rectangle(size=(
        vss_voltage_line.xmax - photodiode.xmax, column_readout.ymax - body_contact.ymin), layer=gf180mcu.LAYER.metal3)
    ground_connection_light_blocker_ref1.xmin = photodiode.xmax
    ground_connection_light_blocker_ref1.ymax = column_readout.ymax

    ground_connection_light_blocker_ref2 = active_pixel << gf.components.rectangle(size=(
        vss_voltage_line.xmax - column_readout.xmin,  column_readout.ysize), layer=gf180mcu.LAYER.metal3)
    ground_connection_light_blocker_ref2.xmax = ground_connection_light_blocker_ref1.xmax
    ground_connection_light_blocker_ref2.ymin = column_readout.ymin

    ground_connection_light_blocker_ref3 = active_pixel << gf.components.rectangle(size=(
        row_reset.xsize, column_readout.ymax - photodiode.ymax), centered=True, layer=gf180mcu.LAYER.metal3)
    ground_connection_light_blocker_ref3.xmin = vss_voltage_line.xmin
    ground_connection_light_blocker_ref3.ymax = column_readout.ymax

    ground_connection_light_blocker_ref4 = active_pixel << gf.components.rectangle(
        size=(row_enable.xsize, 0.28), layer=gf180mcu.LAYER.metal3)
    ground_connection_light_blocker_ref4.xmin = row_enable.xmin
    ground_connection_light_blocker_ref4.ymin = column_readout.ymin

    preffered_poly_width = 0.36
    gf.routing.route_single_electrical(
        component=active_pixel,
        port1=row_reset.ports['via_port1'],
        port2=reset_transistor.ports["e3"],
        width=preffered_poly_width,
        layer=gf180mcu.LAYER.poly2,
        cross_section="metal1"
    )

    min_metal1_width = 0.23
    metal1_cross_section = gf.cross_section.cross_section(
        width=min_metal1_width,
        layer=gf180mcu.LAYER.metal1,
    )

    metal2_cross_section = gf.cross_section.cross_section(
        width=min_metal2_width,
        layer=gf180mcu.LAYER.metal2,
    )

    # Route photodiode N+ to reset transistor.
    gf.routing.route_single_electrical(
        component=active_pixel,
        port1=photodiode_ref.ports["e1"],
        port2=reset_transistor.ports["e1"],
        cross_section=metal1_cross_section,
    )

    # Route source follower to photodiode output, creating a net between
    # source follower, reset transistor, and photodiode
    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=source_follower_nfet.ports["e3"],
        port1=reset_transistor.ports["e1"],
        cross_section=metal1_cross_section,
    )

    # Route VSS to other side of reset to provide reset voltage.
    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=vss_voltage_line.ports["direct_metal_contact"],
        port1=reset_transistor.ports["e2"],
        cross_section=metal1_cross_section,
    )

    spacing_from_column_readout_m2 = 0.33

    top_vss_connect_port = active_pixel << gf.components.rectangle(size=(
        min_metal2_width, min_metal2_width), layer=gf180mcu.LAYER.metal2, port_type="electrical", port_orientations=[270])
    top_vss_connect_port.center = vss_voltage_line.ports["via_port1"].center
    top_vss_connect_port.ymax = active_pixel.ymax

    bottom_vss_connect_port = active_pixel << gf.components.rectangle(size=(
        min_metal2_width, min_metal2_width), layer=gf180mcu.LAYER.metal2, port_type="electrical", port_orientations=[0])
    bottom_vss_connect_port.center = vss_voltage_line.ports["via_port1"].center
    bottom_vss_connect_port.ymin = active_pixel.ymin

    bottom_right_vss_connect_port = active_pixel << gf.components.rectangle(size=(
        min_metal2_width, min_metal2_width), layer=gf180mcu.LAYER.metal2, port_type="electrical", port_orientations=[180, 90])
    bottom_right_vss_connect_port.center = vss_voltage_line.ports["via_port1"].center
    bottom_right_vss_connect_port.ymin = active_pixel.ymin
    bottom_right_vss_connect_port.xmax = column_readout.xmin - \
        spacing_from_column_readout_m2

    right_of_source_follwer_vss_connect_port = active_pixel << gf.components.rectangle(size=(
        min_metal2_width, min_metal2_width), layer=gf180mcu.LAYER.metal2, port_type="electrical", port_orientations=[180, 270])
    right_of_source_follwer_vss_connect_port.center = source_follower_nfet.ports[
        "source_follower_vss_con"].center
    right_of_source_follwer_vss_connect_port.xmax = column_readout.xmin - \
        spacing_from_column_readout_m2

    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=vss_voltage_line.ports["via_port1"],
        port1=source_follower_nfet.ports['source_follower_vss_con'],
        cross_section=metal2_cross_section
    )

    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=top_vss_connect_port.ports["e1"],
        port1=source_follower_nfet.ports['source_follower_vss_con'],
        cross_section=metal2_cross_section
    )

    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=bottom_vss_connect_port.ports["e1"],
        port1=bottom_right_vss_connect_port.ports["e1"],
        cross_section=metal2_cross_section
    )

    source_follower_nfet.ports["source_follower_vss_con"].orientation = 0
    gf.routing.route_single_electrical(
        component=active_pixel,
        port2=source_follower_nfet.ports["source_follower_vss_con"],
        port1=right_of_source_follwer_vss_connect_port.ports["e1"],
        cross_section=metal2_cross_section
    )

    gf.routing.route_single_electrical(
        component=active_pixel,
        port1=right_of_source_follwer_vss_connect_port.ports["e2"],
        port2=bottom_right_vss_connect_port.ports["e2"],
        cross_section=metal2_cross_section
    )

    # Route row enable gate
    gf.routing.route_single_electrical(
        component=active_pixel,
        port1=row_select.ports['e3'],
        port2=row_enable.ports["via_port1"],
        width=preffered_poly_width,
        layer=gf180mcu.LAYER.poly2,
        cross_section="metal1"
    )

    # Create extra nwell to fill out the space
    nwell_extra_ref = active_pixel << gf.components.rectangle(size=(
        body_contact.xmax - photodiode.xmin - 0.07, (body_contact.ymin - 0.4) - row_enable.ymax), layer=gf180mcu.LAYER.nwell)
    nwell_extra_ref.ymin = row_enable.ymax
    nwell_extra_ref.xmin = photodiode.xmin

    rinner = 100
    router = 100
    n = 300  # points in circle

    rounded_nwell = gf.Component()
    for layer, polygons in active_pixel.get_polygons(merge=True, layers=[gf180mcu.LAYER.nwell]).items():
        for polygon in polygons:
            rounded_poly = polygon.round_corners(rinner, router, n)
            rounded_nwell.add_polygon(rounded_poly, layer=layer)

    active_pixel = active_pixel.remove_layers(
        layers=[gf180mcu.LAYER.nwell], unlock=True)
    active_pixel.add_ref(rounded_nwell)

    return active_pixel


gf.kcl.dbu = 5e-3  # set 1 DataBase Unit to 5 nm


gf180mcu.PDK.activate()

com = active_pixel_3t()
c = gf.Component()
c.add_ref(com, rows=1, columns=1, row_pitch=com.xsize, column_pitch=com.ysize)
c.show()
