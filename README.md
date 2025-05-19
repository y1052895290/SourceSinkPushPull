# <img src="SourceSinkPushPull/thumbnail.png" align="left" width=72px> Source-Sink-Push-Pull <br> Opinionated Logistics Train Mod

Thread on the official Factorio Discord: https://discord.com/channels/139677590393716737/1329785565863874610

A logistics train mod that aims to be as pleasant to use as possible, even when knee-deep in byproducts. Compared to similar mods, SSPP places a much greater emphasis on ease of use. The goal of SSPP is to make setting up hundreds of stations in byproduct-heavy overhauls like Py or Seablock nearly effortless. It aims to make many "advanced" use cases that require complex circuitry in other mods into reliable core features.

## Basic Setup

- Use the SSPP shortcut button to open the *network* configuration window.
  - Create a new *class* for your trains.
  - Add a new *item/fluid* to be distributed.
- Open a *train* and switch it to manual.
  - In the bottom right of the screen, choose the *class* you just added.
  - Switch the train back to automatic, and it will go to the depot.
- Create a provider *Station* by building the required entities.
  - Add an entry for the *item/fluid* you just created.
  - Connect the required wires to the station's storage and inserters or pumps.
- Repeat this for a requester *Station*.
- If everything was done correctly, your train should depart for its first job.

Check the sections below for more details on each step.

## Network (Classes)

You must define at least one class of train for each network to make deliveries. A class represents a train layout where every train is interchangeable. For each class, you must define a few things:
- Name: The unique name used to identify this class.
- Depot Name: The name of the vanilla train stops to go to when not busy. They must be configured with a train limit of one, as trains waiting behind others may still be tasked with new deliveries.
- Fueler Name: The name of the vanilla train stops to go to when low on fuel. Required, but may be the same as the depot name. SSPP expects a fueler to always be available, so they should have no train limit, unless they are also depots.
- Bypass Depot (checkbox): When enabled, trains may be given new jobs before arriving at a depot. Disable if you are using double-headed trains and getting "path broken" alerts.

Additionally, from this view you can see the number of available trains for each class. Click the button to see the locations of assigned trains.

## Network (Items/Fluids)

For SSPP to be able to deliver a type of item or fluid, you must add it to a network. For each item or fluid, you must define a few things:
- Class: The name of the class of train that should deliver this item/fluid.
- Delivery Size: The amount of this item/fluid in one delivery. Larger values mean less congestion, but also larger buffers. Usually this will be the maximum that can fit in a train of the specified class, but it may be less for more expensive items.
- Delivery Time: The maximum travel time from any depot to any provider to any requester. Larger values mean larger buffers. This doesn't need to be exact, and if you are unsure, it is better to set it too high than too low. Values between 100 and 200 are reasonable for most bases.

Additionally, from this view you can see current demand and active deliveries for each item/fluid. Click the buttons to see the locations of assigned stations or trains.

## Trains

SSPP adds some extra buttons and information to the bottom right of the train GUI. Here you can assign a network and class to the train. Note that these settings can only be modified when the train is set to manual. Remember to set the train back to automatic when you are done making changes.

The current status of the train is also shown. This will either be information about what the train is currently doing, or if there was a problem, information about what went wrong.

## Stations

A station is, unsurprisingly, where cargo will actually be provided from or requested to. An SSPP station consists of 3 or 4 components:
- One **SSPP Train Stop**.
- One **General IO** combinator.
- One **Provide IO** or **Request IO** combinator, or both.

The combinators should all be placed within 2 tiles of the train stop. Once the components are all placed correctly, you can open the station configuration window by clicking on any of them.

From here, for each item/fluid you want to provide or request, you must define a few things:
- Mode: Controls which stations this station may provide or request to. If set to a push or pull mode, this station will be able to trigger new deliveries. Items/fluids from source stations will **never** be sent to sink stations.
- Throughput: The maximum rate of inflow or outflow of this item/fluid that this station should handle per second. For example, for two full yellow belts, this value would be 30.
- Latency: Extra time in seconds the station should support between deliveries. This accounts for load/unload time, congestion, etc. You will almost always want to leave this at the default value.
- Granularity (provide only): The smallest amount of this item/fluid that can be loaded at a time. This is to prevent overfilling and items/fluids getting stuck. For inserters, this would be the sum of hand sizes.

Once configured, SSPP will then calculate the storage needed for each item/fluid, allowing you to verify that you have enough space to meet the desired throughputs.

You will need to plug in a few wires, but most setups won't need any extra logic:
1. Plug your storage (chests and/or tanks) into the input of the general combinator.
2. Plug your inserters/pumps into the output of the Provide or Request combinator, then configure them to set filters.

For those looking to do more advanced setups, the exact inputs/outputs of each combinator are as follows:
- General In: The contents of this station. Used to decide if new deliveries are needed.
- General Out: Nothing, but reserved for future utility information.
- Provide In: The contents of the stopped train (connected automatically). Control signals for setting provide modes (optional).
- Provide Out: The counts of all items/fluids that still need to be loaded.
- Request In: The contents of the stopped train (connected automatically). Control signals for setting request modes (optional).
- Request Out: The counts of all items/fluids that still need to be unloaded.
