#  CombinePlayground

A small Swift project to demonstrate how to set fields on models with different behvaior.  In this example, updates
from over the network update a model—and by extension the UI but without sending a duplicate event back over the
network—and updates from the UI are sent back out to the network.  In this case, "network" is simply stubbed out with a
`debugPrint` statement.

Originally, the idea was to use Combine directly somehow to communicate these updates, but a simpler version emerged.
