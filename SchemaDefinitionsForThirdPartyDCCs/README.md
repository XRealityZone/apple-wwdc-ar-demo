# Schema definitions for third-party DCCs

Update your local USD library to add interactive and augmented reality features.

## Overview

These schema definition files contain a codified version of the specification addendum defined by [USDZ schemas for AR][1]. As a developer of third-party DCC software, you enable your users to configure interactive and AR features in their 3D assets by implementing the specification and providing additional UI. 

## Integrate interactive and AR schemas

To recognize and validate syntax, and to participate in USD features such as transform hierarchies, incorporate the new interactive and AR schemas into your DCC by copying the `schema.usda` files into your USD library and rebuilding. For more information, see [Generating New Schema Classes][2]. 

[1]:https://developer.apple.com/documentation/arkit/usdz_schemas_for_ar
[2]:https://graphics.pixar.com/usd/docs/Generating-New-Schema-Classes.html
