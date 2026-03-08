import 'package:flutter/material.dart';
import '../../services/geocoding_service.dart';

class SmartSearchBar extends StatefulWidget {
  final String label;
  final IconData prefixIcon;
  final Color iconColor;
  final TextEditingController controller;
  final bool readOnly;
  
  const SmartSearchBar({
    super.key,
    required this.label,
    required this.prefixIcon,
    required this.iconColor,
    required this.controller,
    this.readOnly = false,
  });

  @override
  State<SmartSearchBar> createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<SmartSearchBar> {
  final _geocodingService = GeocodingService();
  
  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      return TextField(
        controller: widget.controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.prefixIcon, color: widget.iconColor),
          border: const OutlineInputBorder(),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<PlaceMatch>(
        initialValue: TextEditingValue(text: widget.controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) async {
          if (textEditingValue.text.length < 3) {
            return const Iterable<PlaceMatch>.empty();
          }
          return await _geocodingService.search(textEditingValue.text);
        },
        displayStringForOption: (PlaceMatch option) => '${option.lat}, ${option.lon}',
        onSelected: (PlaceMatch selection) {
          widget.controller.text = '${selection.lat}, ${selection.lon}';
        },
        fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
          // Sync outward on unfocus or submit
          focusNode.addListener(() {
            if (!focusNode.hasFocus && fieldController.text != widget.controller.text) {
              widget.controller.text = fieldController.text;
            }
          });
          
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: 'Search or enter lat, lon',
              prefixIcon: Icon(widget.prefixIcon, color: widget.iconColor),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  fieldController.clear();
                  widget.controller.clear();
                },
              ),
            ),
            onSubmitted: (val) {
              widget.controller.text = val;
              onFieldSubmitted();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 250, maxWidth: constraints.maxWidth),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, size: 16),
                      title: Text(option.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      subtitle: Text('${option.lat}, ${option.lon}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
