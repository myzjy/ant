#pragma once

#include <core/Geometry.h>

namespace Rml {

class Element;

struct ElementBackgroundImage {
	static bool GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path const& paddingEdge);
	static void GetRectArray(float ratiow, float ratioh, Rect& rect, std::vector<Rect> &rect_array);
};

}
