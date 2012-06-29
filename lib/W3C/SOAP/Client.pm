package W3C::SOAP::Client;

# Created on: 2012-05-28 07:40:20
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use Moose;
use version;
use Carp qw/carp croak cluck confess longmess/;
use Scalar::Util;
use List::Util;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use WWW::Mechanize;
use TryCatch;
use XML::LibXML;
use W3C::SOAP::Exception;
use W3C::SOAP::Header;

our $VERSION     = version->new('0.0.1');
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = ();

has location => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);
has header => (
    is        => 'rw',
    isa       => 'W3C::SOAP::Header',
    predicate => 'has_header',
    builder   => '_header',
);
has mech => (
    is      => 'rw',
    isa     => 'WWW::Mechanize',
    default => sub { WWW::Mechanize->new },
    init_arg => undef,
);

sub request {
    my ($self, $action, $body) = @_;
    my $xml = $self->build_request_xml($action, $body);

    if ( $self->has_header ) {
        my $node = $self->header->to_xml($xml);
        $xml->firstChild->insertBefore($node, $xml->firstChild->firstChild);
    }

    return $self->send($action, $xml);
}

sub build_request_xml {
    my ($self, $action, $body) = @_;
    my $xml = XML::LibXML->load_xml(string => <<'XML');
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
    <soapenv:Body/>
</soapenv:Envelope>
XML

    my $xc = XML::LibXML::XPathContext->new($xml);
    $xc->registerNs('soapenv' => 'http://schemas.xmlsoap.org/soap/envelope/' );
    my ($soap_body) = $xc->findnodes('//soapenv:Body');
    if ( !blessed $body ) {
        $soap_body->appendChild( $xml->createTextNode($body) );
    }
    elsif ( $body->isa('XML::LibXNL::Node') ) {
        $soap_body->appendChild( $body );
    }
    elsif ( $body->can('to_xml') ) {
        for my $node ( $body->to_xml($xml) ) {
            $soap_body->appendChild( $node );
        }
    }
    else {
        W3C::SOAP::Exception::Input->throw(
            faultcode => 'UNKNOWN SOAP BODY',
            message   => "Don't know how to process ". (ref $body) ."\n",
            error     => undef,
        );
    }

    return $xml;
}

sub send {
    my ($self, $action, $xml) = @_;

    my $url = $self->location;

    try {
        $self->mech->post(
            $url,
            'Content-Type'     => 'text/xml;charset=UTF-8',
            'SOAPAction'       => qq{"$action"},
            'Proxy-Connection' => 'Keep-Alive',
            'Accept-Encoding'  => 'gzip, deflate',
            Content            => $xml->toString,
        );
    }
    catch ($e) {
        W3C::SOAP::Exception::HTTP->throw(
            faultcode => $self->mech->res->code,
            message   => $self->mech->res->message,
            error     => $e,
        );
    };

    my $xml_responce = XML::LibXML->load_xml( string => $self->mech->content );
    my %map
        = map {$_->name =~ /^xmlns:?(.*)$/; ($_->value => $1)}
        grep { $_->name =~ /^xmlns/ }
        $xml_responce->firstChild->getAttributes;
    my $ns = $map{'http://schemas.xmlsoap.org/soap/envelope/'};

    my ($node) = $xml_responce->findnodes("//$ns\:Body");

    return $node;
}

sub _header {
    W3C::SOAP::Header->new;
}

1;

__END__

=head1 NAME

W3C::SOAP::Client - Client to talk SOAP to a server.

=head1 VERSION

This documentation refers to W3C::SOAP::Client version 0.1.

=head1 SYNOPSIS

   use W3C::SOAP::Client;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

This module does the actual network connections to a soap server. The clients
generated by L<W3C::SOAP::WSDL::Parser> use this module as their parent.

=head1 SUBROUTINES/METHODS

=over 4

=item C<request ($action, $body)>

Perform a SOAP request to C<location>'s method C<$action> with the object
C<$body> as the SOAP body.

=item C<build_request_xml ($action, $body)>

Builds up the XML of the SOAP request.

=item C<send ($action, $xml)>

Sends the XML (C<$xml>) to the SOAP Server

=back

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)
<Author name(s)>  (<contact address>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW Australia 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
