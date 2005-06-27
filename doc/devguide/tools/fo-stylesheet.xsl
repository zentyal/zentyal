<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    version="1.0">
<!-- The local path to Norm Walsh's DocBook FO stylesheets -->
  <xsl:import href="xsl/fo/docbook.xsl"/>

<xsl:param name="simplesect.in.toc" select="0"/>

<xsl:param name="fop.extensions" select="1" />

<xsl:param name="variablelist.as.blocks" select="1" />

<!--
<xsl:param name="hyphenate.verbatim" select="1"/>
-->

<xsl:param name="alignment">justify</xsl:param>

<xsl:param name="draft.mode" select="'no'"/>

<xsl:param name="footer.rule" select="0"/>

<xsl:param name="header.rule" select="0"/>

<xsl:param name="paper.type" select="'A4'"/>

<xsl:param name="section.autolabel" select="1"/>
<xsl:param name="section.label.includes.component.label" select="1"/>
<xsl:param name="xref.with.number.and.title" select="0"/>


</xsl:stylesheet>
