enum DesignExportFormat { png, svg, pdf }

extension DesignExportFormatName on DesignExportFormat {
  String get extension {
    return switch (this) {
      DesignExportFormat.png => 'png',
      DesignExportFormat.svg => 'svg',
      DesignExportFormat.pdf => 'pdf',
    };
  }
}
